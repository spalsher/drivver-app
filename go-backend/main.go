package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

// WebSocket connection manager
type Hub struct {
	clients      map[*Client]bool
	drivers      map[string]*Client     // driverId -> client
	customers    map[string]*Client     // customerId -> client
	activeRides  map[string]*ActiveRide // rideId -> ride info
	driverStatus map[string]string      // driverId -> "available", "busy", "offline"
	broadcast    chan []byte
	register     chan *Client
	unregister   chan *Client
	mutex        sync.RWMutex
}

type ActiveRide struct {
	RideID     string    `json:"rideId"`
	CustomerID string    `json:"customerId"`
	DriverID   string    `json:"driverId"`
	Status     string    `json:"status"` // "pending", "accepted", "in_progress", "completed"
	PickupLat  float64   `json:"pickupLat"`
	PickupLng  float64   `json:"pickupLng"`
	DestLat    float64   `json:"destLat"`
	DestLng    float64   `json:"destLng"`
	FinalPrice float64   `json:"finalPrice"`
	AcceptedAt time.Time `json:"acceptedAt"`
	DriverLat  float64   `json:"driverLat"`
	DriverLng  float64   `json:"driverLng"`
	DriverETA  int       `json:"driverETA"` // in minutes
}

type Client struct {
	hub      *Hub
	conn     *websocket.Conn
	send     chan []byte
	userID   string
	userType string // "driver" or "customer"
}

type RideRequest struct {
	RideID            string  `json:"rideId"`
	CustomerID        string  `json:"customerId"`
	Pickup            string  `json:"pickup"`
	Destination       string  `json:"destination"`
	PickupLat         float64 `json:"pickupLat"`
	PickupLng         float64 `json:"pickupLng"`
	DestLat           float64 `json:"destLat"`
	DestLng           float64 `json:"destLng"`
	CustomerFareOffer float64 `json:"customerFareOffer"`
	VehicleType       string  `json:"vehicleType"`
	Distance          float64 `json:"distance"`
	Duration          float64 `json:"duration"`
	Timestamp         string  `json:"timestamp"`
}

type DriverOffer struct {
	RideID     string  `json:"rideId"`
	DriverID   string  `json:"driverId"`
	CustomerID string  `json:"customerId"`
	Offer      float64 `json:"offer"`
	Message    string  `json:"message,omitempty"`
	Timestamp  string  `json:"timestamp"`
}

var (
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true // Allow all origins for development
		},
	}

	hub *Hub
	db  *sql.DB
)

func main() {
	// Load environment variables
	godotenv.Load()

	// Initialize database
	initDB()

	// Initialize WebSocket hub
	hub = &Hub{
		clients:      make(map[*Client]bool),
		drivers:      make(map[string]*Client),
		customers:    make(map[string]*Client),
		activeRides:  make(map[string]*ActiveRide),
		driverStatus: make(map[string]string),
		broadcast:    make(chan []byte),
		register:     make(chan *Client),
		unregister:   make(chan *Client),
	}

	// Start WebSocket hub
	go hub.run()

	// Initialize Gin router
	r := gin.Default()

	// CORS configuration
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"*"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Routes
	setupRoutes(r)

	// Start server
	fmt.Println("🚀 Drivrr Go Backend starting on port 8081...")
	fmt.Println("📡 WebSocket endpoint: ws://localhost:8081/ws")
	fmt.Println("🌐 API endpoint: http://localhost:8081/api")

	log.Fatal(r.Run(":8081"))
}

func initDB() {
	var err error
	connStr := "host=localhost user=postgres password=12345678 dbname=drivrr_db sslmode=disable"
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	if err = db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	fmt.Println("✅ Connected to PostgreSQL database")
}

func setupRoutes(r *gin.Engine) {
	// WebSocket endpoint
	r.GET("/ws", handleWebSocket)

	// API routes
	api := r.Group("/api")
	{
		// Health check
		api.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "ok", "backend": "go"})
		})

		// User routes (proxy to existing Node.js for now)
		api.Any("/users/*path", proxyToNode)
		api.Any("/auth/*path", proxyToNode)
	}
}

func proxyToNode(c *gin.Context) {
	// For now, return a simple response
	// In production, we'd proxy to the Node.js backend or migrate these endpoints
	c.JSON(200, gin.H{"message": "Go backend active", "endpoint": c.Request.URL.Path})
}

func handleWebSocket(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("❌ WebSocket upgrade failed: %v", err)
		return
	}

	userID := c.Query("userId")
	userType := c.Query("userType")

	if userID == "" {
		userID = "unknown_" + fmt.Sprintf("%d", time.Now().UnixNano())
	}

	if userType == "" {
		userType = "customer" // default
	}

	client := &Client{
		hub:      hub,
		conn:     conn,
		send:     make(chan []byte, 256),
		userID:   userID,
		userType: userType,
	}

	client.hub.register <- client

	log.Printf("✅ %s %s connected via WebSocket", userType, userID)

	// Start goroutines
	go client.writePump()
	go client.readPump()
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mutex.Lock()
			h.clients[client] = true

			if client.userType == "driver" {
				h.drivers[client.userID] = client
				h.driverStatus[client.userID] = "available" // Default to available
				log.Printf("🚗 Driver %s registered. Total drivers: %d", client.userID, len(h.drivers))
			} else {
				h.customers[client.userID] = client
				log.Printf("👤 Customer %s registered. Total customers: %d", client.userID, len(h.customers))
			}
			h.mutex.Unlock()

		case client := <-h.unregister:
			h.mutex.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)

				if client.userType == "driver" {
					delete(h.drivers, client.userID)
					h.driverStatus[client.userID] = "offline"
					log.Printf("🚗 Driver %s disconnected. Total drivers: %d", client.userID, len(h.drivers))
				} else {
					delete(h.customers, client.userID)
					log.Printf("👤 Customer %s disconnected. Total customers: %d", client.userID, len(h.customers))
				}
			}
			h.mutex.Unlock()

		case message := <-h.broadcast:
			h.mutex.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mutex.RUnlock()
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(512)
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("❌ WebSocket error: %v", err)
			}
			break
		}

		// Handle incoming messages
		c.handleMessage(message)
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) handleMessage(message []byte) {
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		log.Printf("❌ Invalid JSON message: %v", err)
		return
	}

	msgType, ok := msg["type"].(string)
	if !ok {
		log.Printf("❌ Message missing type field")
		return
	}

	switch msgType {
	case "create_ride_request":
		c.handleRideRequest(msg)
	case "driver_offer":
		c.handleDriverOffer(msg)
	case "accept_offer":
		c.handleAcceptOffer(msg)
	case "driver_status":
		c.handleDriverStatus(msg)
	case "driver_location_update":
		c.handleDriverLocationUpdate(msg)
	case "complete_ride":
		c.handleCompleteRide(msg)
	case "ping":
		c.handlePing()
	default:
		log.Printf("⚠️ Unknown message type: %s", msgType)
	}
}

func (c *Client) handleRideRequest(msg map[string]interface{}) {
	log.Printf("🚗 NEW RIDE REQUEST from %s", c.userID)

	// Generate ride ID
	rideID := fmt.Sprintf("ride_%d", time.Now().UnixNano())

	// Create ride request
	rideRequest := RideRequest{
		RideID:            rideID,
		CustomerID:        c.userID,
		Pickup:            getString(msg, "pickup"),
		Destination:       getString(msg, "destination"),
		PickupLat:         getFloat(msg, "pickupLat"),
		PickupLng:         getFloat(msg, "pickupLng"),
		DestLat:           getFloat(msg, "destLat"),
		DestLng:           getFloat(msg, "destLng"),
		CustomerFareOffer: getFloat(msg, "customerFareOffer"),
		VehicleType:       getString(msg, "vehicleType"),
		Distance:          getFloat(msg, "distance"),
		Duration:          getFloat(msg, "duration"),
		Timestamp:         time.Now().Format(time.RFC3339),
	}

	log.Printf("📡 Broadcasting to %d drivers: %s → %s (PKR %.0f)",
		len(c.hub.drivers), rideRequest.Pickup, rideRequest.Destination, rideRequest.CustomerFareOffer)

	// Broadcast to all drivers
	c.hub.mutex.RLock()
	for _, driver := range c.hub.drivers {
		response := map[string]interface{}{
			"type": "new_ride_request",
			"data": rideRequest,
		}

		if data, err := json.Marshal(response); err == nil {
			select {
			case driver.send <- data:
				log.Printf("✅ Sent ride request to driver %s", driver.userID)
			default:
				log.Printf("❌ Failed to send to driver %s", driver.userID)
			}
		}
	}
	c.hub.mutex.RUnlock()

	log.Printf("🎯 Ride request %s broadcasted to all drivers", rideID)
}

func (c *Client) handleDriverOffer(msg map[string]interface{}) {
	c.hub.mutex.RLock()
	driverStatus := c.hub.driverStatus[c.userID]
	c.hub.mutex.RUnlock()

	// Validate driver can only accept one ride at a time
	if driverStatus == "busy" {
		log.Printf("❌ Driver %s is busy and cannot accept new rides", c.userID)

		// Send rejection back to driver
		response := map[string]interface{}{
			"type": "offer_rejected",
			"data": map[string]interface{}{
				"reason":  "You already have an active ride",
				"message": "Complete your current ride before accepting new ones",
			},
		}

		if data, err := json.Marshal(response); err == nil {
			select {
			case c.send <- data:
			default:
			}
		}
		return
	}

	log.Printf("💰 Driver offer from %s (Status: %s)", c.userID, driverStatus)

	offer := DriverOffer{
		RideID:     getString(msg, "rideId"),
		DriverID:   c.userID,
		CustomerID: getString(msg, "customerId"),
		Offer:      getFloat(msg, "offer"),
		Message:    getString(msg, "message"),
		Timestamp:  time.Now().Format(time.RFC3339),
	}

	// Send offer to customer
	c.hub.mutex.RLock()
	if customer, exists := c.hub.customers[offer.CustomerID]; exists {
		response := map[string]interface{}{
			"type": "driver_offer",
			"data": offer,
		}

		if data, err := json.Marshal(response); err == nil {
			select {
			case customer.send <- data:
				log.Printf("✅ Sent offer to customer %s: PKR %.0f", offer.CustomerID, offer.Offer)
			default:
				log.Printf("❌ Failed to send offer to customer %s", offer.CustomerID)
			}
		}
	}
	c.hub.mutex.RUnlock()
}

func (c *Client) handleAcceptOffer(msg map[string]interface{}) {
	log.Printf("✅ Offer accepted by customer %s", c.userID)

	rideID := getString(msg, "rideId")
	driverID := getString(msg, "driverId")
	finalPrice := getFloat(msg, "finalPrice")
	pickupLat := getFloat(msg, "pickupLat")
	pickupLng := getFloat(msg, "pickupLng")
	destLat := getFloat(msg, "destLat")
	destLng := getFloat(msg, "destLng")

	c.hub.mutex.Lock()

	// Set driver status to busy
	c.hub.driverStatus[driverID] = "busy"

	// Calculate driver ETA (mock calculation - in real app, use Google Maps API)
	driverETA := calculateDriverETA(pickupLat, pickupLng) // 3-8 minutes

	// Create active ride
	activeRide := &ActiveRide{
		RideID:     rideID,
		CustomerID: c.userID,
		DriverID:   driverID,
		Status:     "accepted",
		PickupLat:  pickupLat,
		PickupLng:  pickupLng,
		DestLat:    destLat,
		DestLng:    destLng,
		FinalPrice: finalPrice,
		AcceptedAt: time.Now(),
		DriverLat:  pickupLat + 0.01, // Mock driver location nearby
		DriverLng:  pickupLng + 0.01,
		DriverETA:  driverETA,
	}

	c.hub.activeRides[rideID] = activeRide
	c.hub.mutex.Unlock()

	log.Printf("🚗 Driver %s is now BUSY with ride %s", driverID, rideID)
	log.Printf("📍 Driver ETA: %d minutes", driverETA)

	// Notify driver
	c.hub.mutex.RLock()
	if driver, exists := c.hub.drivers[driverID]; exists {
		response := map[string]interface{}{
			"type": "offer_accepted",
			"data": map[string]interface{}{
				"rideId":     rideID,
				"finalPrice": finalPrice,
				"customerId": c.userID,
				"status":     "accepted",
				"pickupLat":  pickupLat,
				"pickupLng":  pickupLng,
				"destLat":    destLat,
				"destLng":    destLng,
			},
		}

		if data, err := json.Marshal(response); err == nil {
			select {
			case driver.send <- data:
				log.Printf("✅ Notified driver %s of acceptance", driverID)
			default:
				log.Printf("❌ Failed to notify driver %s", driverID)
			}
		}
	}

	// Send driver info and ETA to customer
	if customer, exists := c.hub.customers[c.userID]; exists {
		customerResponse := map[string]interface{}{
			"type": "driver_assigned",
			"data": map[string]interface{}{
				"rideId":     rideID,
				"driverId":   driverID,
				"driverName": "Driver " + driverID[:8], // Mock name
				"driverLat":  activeRide.DriverLat,
				"driverLng":  activeRide.DriverLng,
				"driverETA":  driverETA,
				"finalPrice": finalPrice,
				"status":     "driver_assigned",
				"message":    fmt.Sprintf("Driver will arrive in %d minutes", driverETA),
			},
		}

		if data, err := json.Marshal(customerResponse); err == nil {
			select {
			case customer.send <- data:
				log.Printf("✅ Sent driver details to customer %s", c.userID)
			default:
				log.Printf("❌ Failed to send driver details to customer %s", c.userID)
			}
		}
	}
	c.hub.mutex.RUnlock()
}

// Calculate driver ETA based on distance (mock implementation)
func calculateDriverETA(pickupLat, pickupLng float64) int {
	// Mock calculation - in real app, use Google Maps Distance Matrix API
	// For now, return random ETA between 3-8 minutes
	return 3 + int(time.Now().UnixNano()%6) // 3-8 minutes
}

func (c *Client) handleDriverStatus(msg map[string]interface{}) {
	isOnline := getBool(msg, "isOnline")

	c.hub.mutex.Lock()
	if isOnline {
		// Only set to available if not currently busy
		if c.hub.driverStatus[c.userID] != "busy" {
			c.hub.driverStatus[c.userID] = "available"
		}
	} else {
		c.hub.driverStatus[c.userID] = "offline"
	}
	status := c.hub.driverStatus[c.userID]
	c.hub.mutex.Unlock()

	log.Printf("🚗 Driver %s is now %s (Status: %s)", c.userID, map[bool]string{true: "ONLINE", false: "OFFLINE"}[isOnline], status)
}

func (c *Client) handleDriverLocationUpdate(msg map[string]interface{}) {
	rideID := getString(msg, "rideId")
	lat := getFloat(msg, "latitude")
	lng := getFloat(msg, "longitude")

	log.Printf("📍 Driver %s location update for ride %s: %.6f, %.6f", c.userID, rideID, lat, lng)

	c.hub.mutex.Lock()
	if ride, exists := c.hub.activeRides[rideID]; exists {
		ride.DriverLat = lat
		ride.DriverLng = lng

		// Recalculate ETA based on new location
		ride.DriverETA = calculateDriverETA(ride.PickupLat, ride.PickupLng)
		c.hub.activeRides[rideID] = ride
	}
	c.hub.mutex.Unlock()

	// Send location update to customer
	c.hub.mutex.RLock()
	if ride, exists := c.hub.activeRides[rideID]; exists {
		if customer, exists := c.hub.customers[ride.CustomerID]; exists {
			response := map[string]interface{}{
				"type": "driver_location_update",
				"data": map[string]interface{}{
					"rideId":    rideID,
					"driverId":  c.userID,
					"latitude":  lat,
					"longitude": lng,
					"eta":       ride.DriverETA,
					"timestamp": time.Now().Format(time.RFC3339),
				},
			}

			if data, err := json.Marshal(response); err == nil {
				select {
				case customer.send <- data:
					log.Printf("📲 Sent location update to customer %s", ride.CustomerID)
				default:
					log.Printf("❌ Failed to send location update to customer %s", ride.CustomerID)
				}
			}
		}
	}
	c.hub.mutex.RUnlock()
}

func (c *Client) handleCompleteRide(msg map[string]interface{}) {
	rideID := getString(msg, "rideId")

	log.Printf("🏁 Ride %s completed by driver %s", rideID, c.userID)

	c.hub.mutex.Lock()
	if ride, exists := c.hub.activeRides[rideID]; exists {
		// Set driver back to available
		c.hub.driverStatus[c.userID] = "available"

		// Remove active ride
		delete(c.hub.activeRides, rideID)

		log.Printf("✅ Driver %s is now AVAILABLE again", c.userID)

		// Notify customer that ride is completed
		c.hub.mutex.Unlock()
		c.hub.mutex.RLock()
		if customer, exists := c.hub.customers[ride.CustomerID]; exists {
			response := map[string]interface{}{
				"type": "ride_completed",
				"data": map[string]interface{}{
					"rideId":     rideID,
					"driverId":   c.userID,
					"finalPrice": ride.FinalPrice,
					"status":     "completed",
					"timestamp":  time.Now().Format(time.RFC3339),
				},
			}

			if data, err := json.Marshal(response); err == nil {
				select {
				case customer.send <- data:
					log.Printf("✅ Notified customer %s of ride completion", ride.CustomerID)
				default:
					log.Printf("❌ Failed to notify customer %s of completion", ride.CustomerID)
				}
			}
		}
		c.hub.mutex.RUnlock()
	} else {
		c.hub.mutex.Unlock()
		log.Printf("❌ Ride %s not found for completion", rideID)
	}
}

func (c *Client) handlePing() {
	log.Printf("🏓 Ping from %s (%s)", c.userID, c.userType)

	// Send pong response
	response := map[string]interface{}{
		"type":      "pong",
		"timestamp": time.Now().Format(time.RFC3339),
	}

	if data, err := json.Marshal(response); err == nil {
		select {
		case c.send <- data:
			log.Printf("🏓 Pong sent to %s", c.userID)
		default:
			log.Printf("❌ Failed to send pong to %s", c.userID)
		}
	}
}

// Helper functions
func getString(msg map[string]interface{}, key string) string {
	if val, ok := msg[key].(string); ok {
		return val
	}
	return ""
}

func getFloat(msg map[string]interface{}, key string) float64 {
	if val, ok := msg[key].(float64); ok {
		return val
	}
	return 0
}

func getBool(msg map[string]interface{}, key string) bool {
	if val, ok := msg[key].(bool); ok {
		return val
	}
	return false
}

func healthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":      "ok",
		"backend":     "go",
		"drivers":     len(hub.drivers),
		"customers":   len(hub.customers),
		"connections": len(hub.clients),
		"timestamp":   time.Now().Format(time.RFC3339),
	})
}
