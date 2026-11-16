import type { Instrumentation } from "next";

/**
 * Next.js calls this for every unhandled server error (5xx). We record the
 * route, method and error text only -- never headers or request bodies.
 */
export const onRequestError: Instrumentation.onRequestError = async (error, request, context) => {
  const err = error as { name?: string; message?: string; stack?: string };
  const { reportError } = await import("@/lib/telemetry/errors");
  await reportError(
    { name: err.name, message: err.message ?? "Unknown error", stack: err.stack },
    {
      source: "api",
      route: context.routePath,
      method: request.method,
      status: 500,
    },
  );
};
