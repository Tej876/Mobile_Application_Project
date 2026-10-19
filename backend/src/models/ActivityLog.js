const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema(
  {
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      required: [true, 'Department ID is required'],
      index: true,
    },
    tokenId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'QueueToken',
      default: null,
    },
    tokenNumber: {
      type: Number,
      default: null,
    },
    patientName: {
      type: String,
      default: '',
    },
    actorId: {
      type: String,
      required: [true, 'Actor ID is required'],
      index: true,
    },
    action: {
      type: String,
      required: [true, 'Action is required'],
      enum: [
        'token_created',
        'token_cancelled',
        'token_called',
        'token_served',
        'token_no_show',
        'notification_dispatched',
        'email_sent',
        'CONFIRMATION_EMAIL_SENT',
        'cancelled',
        'served',
        'no_show',
      ],
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    collection: 'activity_logs',
    timestamps: false,
    toJSON: {
      virtuals: true,
      transform: (doc, ret) => {
        ret.id = ret._id.toString();
        ret.departmentId = ret.departmentId?.toString() || ret.departmentId;
        ret.tokenId = ret.tokenId?.toString() || ret.tokenId;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Compound index for admin audit history queries
activityLogSchema.index({ departmentId: 1, timestamp: -1 });

const ActivityLog = mongoose.model('ActivityLog', activityLogSchema);
module.exports = ActivityLog;
