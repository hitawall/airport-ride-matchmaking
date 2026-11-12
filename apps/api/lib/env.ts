function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

export const env = {
  get jwtSecret() {
    return required("JWT_SECRET");
  },
  get msg91AuthKey() {
    return required("MSG91_AUTH_KEY");
  },
  get msg91TemplateId() {
    return required("MSG91_TEMPLATE_ID");
  },
  get pusherAppId() {
    return required("PUSHER_APP_ID");
  },
  get pusherKey() {
    return required("PUSHER_KEY");
  },
  get pusherSecret() {
    return required("PUSHER_SECRET");
  },
  get pusherCluster() {
    return required("PUSHER_CLUSTER");
  },
  get cronSecret() {
    return required("CRON_SECRET");
  },
};
