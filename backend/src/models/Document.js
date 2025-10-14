const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  driverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  documentType: {
    type: String,
    required: true,
    enum: [
      'drivingLicense',
      'vehicleRegistration',
      'insuranceCertificate',
      'driverPhoto',
      'vehiclePhoto'
    ],
  },
  filePath: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    required: true,
    enum: ['uploaded', 'under_review', 'approved', 'rejected'],
    default: 'under_review',
  },
  rejectionReason: {
    type: String,
    default: null,
  },
  uploadedAt: {
    type: Date,
    default: Date.now,
  },
  reviewedAt: {
    type: Date,
    default: null,
  },
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
}, {
  timestamps: true,
});

// Compound index for efficient queries
documentSchema.index({ driverId: 1, documentType: 1 }, { unique: true });

// Instance methods
documentSchema.methods.approve = function(reviewerId) {
  this.status = 'approved';
  this.reviewedAt = new Date();
  this.reviewedBy = reviewerId;
  this.rejectionReason = null;
  return this.save();
};

documentSchema.methods.reject = function(reviewerId, reason) {
  this.status = 'rejected';
  this.reviewedAt = new Date();
  this.reviewedBy = reviewerId;
  this.rejectionReason = reason;
  return this.save();
};

// Static methods
documentSchema.statics.getDriverDocuments = function(driverId) {
  return this.find({ driverId }).sort({ updatedAt: -1 });
};

documentSchema.statics.getPendingDocuments = function() {
  return this.find({ status: 'under_review' })
    .populate('driverId', 'name phone email')
    .sort({ uploadedAt: -1 });
};

documentSchema.statics.getVerificationStats = function(driverId) {
  return this.aggregate([
    { $match: { driverId: mongoose.Types.ObjectId(driverId) } },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 }
      }
    }
  ]);
};

// Pre-save middleware
documentSchema.pre('save', function(next) {
  if (this.isModified('status')) {
    if (this.status === 'approved' || this.status === 'rejected') {
      if (!this.reviewedAt) {
        this.reviewedAt = new Date();
      }
    }
  }
  next();
});

// Virtual for document age
documentSchema.virtual('documentAge').get(function() {
  return Math.floor((Date.now() - this.uploadedAt) / (1000 * 60 * 60 * 24)); // days
});

// Virtual for review time
documentSchema.virtual('reviewTime').get(function() {
  if (this.reviewedAt && this.uploadedAt) {
    return Math.floor((this.reviewedAt - this.uploadedAt) / (1000 * 60 * 60)); // hours
  }
  return null;
});

// Transform output
documentSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

const Document = mongoose.model('Document', documentSchema);

module.exports = Document;
