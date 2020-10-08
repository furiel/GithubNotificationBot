(import time)
(import json)
(import urllib.parse)
(import http.client urllib.parse)
(import base64)
(import collections)
(require [hy.extra.anaphoric [*]])

(defn to-string [x]
  (or (and (isinstance x str) x)
      (and (isinstance x bytes) (.decode x))))

(defn get-latest-comment [url-raw githubconn]
  (setv url (. (urllib.parse.urlparse url-raw) path)
        latest-comment-response (.request githubconn url))

  (setv latest-comment
        (try
          (json.loads latest-comment-response)
          (except [e Exception]
            (print "Exception occured while parsing latest comment:" latest-comment-url latest-comment-response e :flush True))))

  (try
    (.format "user: {}\nmessage: {}\nlink: {}\n"
             (get latest-comment "user" "login")
             (get latest-comment "body")
             (get latest-comment "html_url"))
    (except [e Exception]
      (print "Exception while formatting latest comment" latest-comment-url latest-comment-response e :flush True)
      "")))

(defn format-single-notification [notification githubconn]
  (setv
    latest-comment-url (get notification "subject" "latest_comment_url")
    latest-comment (ap-if latest-comment-url (get-latest-comment it githubconn) "")
    formatted-notification
    (try
      (.format "title: {}\ntype: {}\n"
               (get notification "subject" "title")
               (get notification "subject" "type"))
      (except [e Exception]
        (print "Exception occured while formatting notification" notification e :flush True)
        "exception occured\n")))

  (.format "{}{}" formatted-notification latest-comment))


(defn parse-notifications [notifications-json githubconn]
  (setv notifications (json.loads notifications-json))
  (lfor notification notifications (format-single-notification notification githubconn)))

(defclass GithubConnection [object]
  (defn --init-- [self username api-token]
    (setv basic-auth-secret
          (.decode
            (base64.b64encode
              (.encode (.format "{}:{}" username api-token)))))
    (setv self.headers
          {"Content-type" "application/x-www-form-urlencoded"
           "Accept" "application/json"
           "User-Agent" "notification-bot"
           "Authorization" (.format "Basic {}" basic-auth-secret) }))

  (defn connect [self &optional [host "api.github.com"] [context None]]
    (setv self.conn (http.client.HTTPSConnection host :context context))
    self.conn)

  (defn disconnect [self]
    (.close self.conn))

  (defn request [self url &optional [method "GET"]]
    (try
      ;; Simple way of throttling: github terminates connection if too many messages are sent at once
      (time.sleep 1)
      (.request self.conn :method method :url url :headers self.headers)
      (setv response (.getresponse self.conn))
      (setv status (int response.status))
      (setv response-string (to-string (response.read)))
      (setv reason response.reason)

      (if (= 2 (// status 100))
          response-string
          reason)
      (except [e Exception]
        (print "Exception during fetch: " url status response-string e :flush True)
        "Fetch failed"))))

(defn fetch-notifications [username api-token]
  (setv githubconn (GithubConnection username api-token))
  (.connect githubconn)

  (setv notifications
        (parse-notifications
          (.request githubconn "/notifications")
          githubconn))

  (.request githubconn "/notifications" :method "PUT")
  (.disconnect githubconn)

  notifications)
