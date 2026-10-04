import { Queue } from "bullmq";
import { CloudWatchClient, PutMetricDataCommand } from "@aws-sdk/client-cloudwatch";

const cloudwatch = new CloudWatchClient({});

// Uses the real bullmq Queue class rather than reading BullMQ's internal
// Redis keys directly — a couple more milliseconds per invocation, but it
// stays correct across BullMQ version bumps instead of silently drifting
// if BullMQ's internal key layout ever changes.
export const handler = async () => {
  const queue = new Queue(process.env.QUEUE_NAME, {
    connection: {
      host: process.env.REDIS_HOST,
      port: Number(process.env.REDIS_PORT ?? 6379),
    },
  });

  try {
    const waitingCount = await queue.getWaitingCount();

    await cloudwatch.send(
      new PutMetricDataCommand({
        Namespace: process.env.METRIC_NAMESPACE,
        MetricData: [
          {
            MetricName: process.env.METRIC_NAME,
            Value: waitingCount,
            Unit: "Count",
          },
        ],
      }),
    );
  } finally {
    // Closed every invocation (not kept warm) — at one call per minute,
    // the simplicity of a clean connect/query/close is worth more than
    // the small latency saving from reusing a connection across
    // invocations, and it avoids slowly accumulating idle connections
    // against Redis's maxclients over the life of the Lambda.
    await queue.close();
  }
};
