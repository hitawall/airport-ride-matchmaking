// "Continue with Google". Opens Google's own sign-in popup and hands the app an
// access token, which the app sends to our API; the API asks Google who it
// belongs to. We never see the person's Google password.
//
// Google's script is only downloaded the first time someone taps the button.
(function () {
  var SCRIPT_URL = "https://accounts.google.com/gsi/client";
  var loading = null;

  function load() {
    if (window.google && window.google.accounts && window.google.accounts.oauth2) return Promise.resolve();
    if (!loading) {
      loading = new Promise(function (resolve, reject) {
        var script = document.createElement("script");
        script.src = SCRIPT_URL;
        script.async = true;
        script.onload = resolve;
        script.onerror = function () { reject(new Error("load")); };
        document.head.appendChild(script);
      });
      loading.catch(function () { loading = null; }); // allow a retry after a network failure
    }
    return loading;
  }

  // Resolves with a JSON string: {accessToken}, {cancelled: true} or {error}.
  window.airpoolGoogle = {
    requestAccessToken: function (clientId) {
      return load().then(
        function () {
          return new Promise(function (resolve) {
            try {
              var client = window.google.accounts.oauth2.initTokenClient({
                client_id: clientId,
                scope: "openid email profile",
                callback: function (response) {
                  if (response && response.access_token) {
                    resolve(JSON.stringify({ accessToken: response.access_token }));
                  } else if (response && response.error === "access_denied") {
                    resolve(JSON.stringify({ cancelled: true }));
                  } else {
                    resolve(JSON.stringify({ error: "Google sign-in didn't finish. Please try again." }));
                  }
                },
                error_callback: function (err) {
                  var type = err && err.type;
                  if (type === "popup_closed") resolve(JSON.stringify({ cancelled: true }));
                  else if (type === "popup_failed_to_open")
                    resolve(JSON.stringify({ error: "Your browser blocked the Google window. Allow pop-ups for this site and try again." }));
                  else resolve(JSON.stringify({ error: "Google sign-in didn't finish. Please try again." }));
                },
              });
              client.requestAccessToken();
            } catch (e) {
              resolve(JSON.stringify({ error: "Google sign-in isn't available right now." }));
            }
          });
        },
        function () {
          return JSON.stringify({ error: "We couldn't reach Google. Check your connection and try again." });
        },
      );
    },
  };
})();
