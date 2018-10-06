(import sys)
(import syslogng threading)
(import githubnotificationfetcher)

(defclass GithubNotificationSource [syslogng.LogSource]
  (defn init [self options]
    (setv self.event (threading.Event)
          self.exit False)

    (setv self.username (get options "username")
          self.api-token (get options "api_token"))
    True)

  (defn run [self]
    (while (not self.exit)

      (for [notification (githubnotificationfetcher.fetch-notifications self.username self.api-token)]
        (self.post_message (syslogng.LogMessage notification)))
      (sys.stdout.flush)

      (self.event.wait 300)))

   (defn request-exit [self]
     (setv self.exit True)
     (self.event.set)))
