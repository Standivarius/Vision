const APP_IDENTITY = Object.freeze({
  service: "doxa-visual-assistant",
  difyAppId: "c94b6e55-3f7f-4b8f-a2d2-99fe960959a1",
  difyAppName: "Visual Assistant",
  configuredModelId: "muse-spark-1.3-contributor",
  configuredModelName: "Muse Spark 1.3 Contributor",
});

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function normalizeContext(value) {
  const input = value && typeof value === "object" && !Array.isArray(value) ? value : {};
  const bool = (name) => input[name] === true;
  const zoom = Number(input.zoom);
  const monitorCount = Number(input.monitor_count);
  const allowedModes = new Set(["normal", "increase_contrast", "inverted_colours", "grayscale"]);
  const visualMode = allowedModes.has(String(input.visual_mode || ""))
    ? String(input.visual_mode)
    : "normal";

  return {
    zoom: Number.isFinite(zoom) && zoom >= 1 && zoom <= 8 ? zoom : 1,
    tracking_enabled: bool("tracking_enabled"),
    follow_pointer: bool("follow_pointer"),
    follow_text_cursor: bool("follow_text_cursor"),
    follow_keyboard_focus: bool("follow_keyboard_focus"),
    pointer_locator: bool("pointer_locator"),
    text_cursor_highlight: bool("text_cursor_highlight"),
    focus_highlight: bool("focus_highlight"),
    view_locator: bool("view_locator"),
    visual_mode: visualMode,
    monitor_count: Number.isFinite(monitorCount) ? Math.max(0, Math.min(16, Math.trunc(monitorCount))) : 0,
    single_monitor: bool("single_monitor"),
    context_assigned: bool("context_assigned"),
    detail_assigned: bool("detail_assigned"),
    reference_assigned: bool("reference_assigned"),
  };
}

function buildQuery(question, context) {
  return `User question:\n${question}\n\nCurrent Visual state (structured application state; not screen content):\n${JSON.stringify(context)}\n\nAnswer the user's question using the Visual Assistant instructions. Keep the answer concise and actionable.`;
}

async function callDify(env, question, context) {
  if (!env.DIFY_API_KEY) throw new Error("assistant_not_configured");

  const response = await fetch("https://api.dify.ai/v1/chat-messages", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.DIFY_API_KEY}`,
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      inputs: {},
      query: buildQuery(question, context),
      response_mode: "blocking",
      conversation_id: "",
      user: "visual-desktop",
    }),
  });

  if (!response.ok) throw new Error(`assistant_upstream_${response.status}`);
  const payload = await response.json();
  if (!payload || typeof payload.answer !== "string" || !payload.answer.trim()) {
    throw new Error("assistant_invalid_response");
  }

  return {
    answer: payload.answer.trim().slice(0, 12000),
    taskId: typeof payload.task_id === "string" ? payload.task_id : "",
    messageId: typeof payload.message_id === "string"
      ? payload.message_id
      : (typeof payload.id === "string" ? payload.id : ""),
  };
}

function authorizedPath(url, env) {
  if (!env.VISUAL_ROUTE_TOKEN) return false;
  const expected = `/v1/ask/${env.VISUAL_ROUTE_TOKEN}`;
  return url.pathname === expected;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: APP_IDENTITY.service,
        schema_version: "1",
        provider: "dify",
        dify_app_id: APP_IDENTITY.difyAppId,
        dify_app_name: APP_IDENTITY.difyAppName,
        configured_model_id: APP_IDENTITY.configuredModelId,
        configured_model_name: APP_IDENTITY.configuredModelName,
        model_identity_source: "worker_config",
      });
    }

    if (request.method !== "POST" || !authorizedPath(url, env)) {
      return json({ error: "not_found" }, 404);
    }

    const contentLength = Number(request.headers.get("content-length") || 0);
    if (contentLength > 32768) return json({ error: "request_too_large" }, 413);

    let input;
    try {
      input = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    if (!input || input.schema_version !== "1" || input.intent !== "ask_visual") {
      return json({ error: "invalid_request" }, 400);
    }

    const question = typeof input.question === "string" ? input.question.trim() : "";
    if (!question || question.length > 2000) {
      return json({ error: "invalid_question" }, 400);
    }

    const context = normalizeContext(input.context);

    try {
      const result = await callDify(env, question, context);
      return json({
        schema_version: "1",
        title: "Ask Visual",
        answer: result.answer,
        provider: "dify",
        dify_app_id: APP_IDENTITY.difyAppId,
        configured_model_id: APP_IDENTITY.configuredModelId,
        configured_model_name: APP_IDENTITY.configuredModelName,
        trace: {
          task_id: result.taskId,
          message_id: result.messageId,
        },
      });
    } catch (error) {
      const code = String(error?.message || "assistant_failed");
      return json({ error: "assistant_failed", code }, 502);
    }
  },
};