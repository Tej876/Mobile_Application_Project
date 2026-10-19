const mongoose = require('mongoose');

const queueTokenSchema = new mongoose.Schema(
  {
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      required: [true, 'Department ID is required'],
      index: true,
    },
    patientId: {
      type: String,
      required: [true, 'Patient ID (Firebase UID) is required'],
      trim: true,
    },
    patientName: {
      type: String,
      required: [true, 'Patient name is required'],
      trim: true,
    },
    tokenNumber: {
      type: Number,
      required: true,
      min: 1,
    },
    status: {
      type: String,
      enum: ['waiting', 'called', 'served', 'cancelled', 'no_show'],
      default: 'waiting',
      index: true,
    },
    joinedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    calledAt: {
      type: Date,
      default: null,
    },
    servedAt: {
      type: Date,
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    notifiedAt: {
      type: Date,
      default: null,
    },
  },
  {
    collection: 'queue_tokens',
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: (doc, ret) => {
        ret.id = ret._id.toString();
        ret.departmentId = ret.departmentId?.toString() || ret.departmentId;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Compound index for deterministic and fast queue retrieval
queueTokenSchema.index({ departmentId: 1, status: 1, joinedAt: 1, _id: 1 });

// Partial unique index: guarantees AT MOST ONE active booking ('waiting' or 'called') per patient at the database level!
queueTokenSchema.index(
  { patientId: 1 },
  {
    unique: true,
    partialFilterExpression: {
      status: { $in: ['waiting', 'called'] },
    },
  }
);

const QueueToken = mongoose.model('QueueToken', queueTokenSchema);
module.exports = QueueToken;
