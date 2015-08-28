; program purpose: 
;   inject watching websocket code into html page being served, refresh served page on 
;   file-system change (or other synchronizable event, in this case just file-system)
;
;   built to make it easier to get a fast workflow with luxe primarily
;
;   requires: rfc6455 - websocket library

#lang racket

(require (prefix-in x: xml) (prefix-in h: html))
(require net/rfc6455)
(require racket/cmdline)
(require web-server/servlet
         web-server/servlet-env)

; constants?
(define web-port 8000)
(define ws-port 8001)
(define wait-time 0.1)

; global variables
(define page-content (x:string->xexpr "<html></html>"))
(x:permissive-xexprs #t)

; command line arguments config
(define index-file (make-parameter "index.html"))
(define watched-directory (make-parameter "."))
(define command-to-run (command-line
    #:program "refresher"
    #:once-each
    [("-i" "--index-file") file
                            "HTML index file to serve."
                            (index-file file)]
    [("-d" "--directory") dir
                          "Directory to watch for changes."
                          (watched-directory dir)]
    #:args (command)
    command))

; injected code
(define injected-code 
  "<script>
  (function() {
    var ws = new WebSocket(\"ws://localhost:8001\");

    ws.onmessage = function(evt) {
      window.location.reload();
    }

   })();
  </script>")

(define injected-xml (x:string->xexpr injected-code))

; utility functions
(define (inject-listener in-xml)
  (define xml-data (h:read-html-as-xml in-xml))
  (define xml-structure (x:xml->xexpr (x:element #f #f 'html '() xml-data)))
  (append xml-structure (list injected-xml)))

(define (reload-index file-name)
  (sleep wait-time) ; make a retry function instead next
  (call-with-input-file file-name
    (lambda (in) (inject-listener in))))

; listeners
(define (change-listener directory target-thread)
    (define change-event (filesystem-change-evt directory))
  (define change (sync change-event)) ; sync on change - do things when shit happens!
  (thread-send target-thread #t)
  (change-listener directory target-thread))

(define (websocket-listener port owner-thread)
  (ws-serve #:port port (curry handle-connection owner-thread)))

(define (handle-connection owner-thread c state)
  (thread-send owner-thread (current-thread))
  (define sent-event (sync (thread-receive-evt)))
  (ws-send! c (~a sent-event)))

(define (page-servlet req)
  (response/xexpr page-content))

(define (do-servlet servlet-func dir)
  (serve/servlet servlet-func
                 #:servlet-path "/"
                 #:extra-files-paths
                 (list (build-path (string->path dir)))))

(define (start-listener index directory command)
  (define this-thread (current-thread))
  (set! page-content (reload-index index)) ; initial load of data
  (define change-thread (thread (lambda () (change-listener directory this-thread))))
  (define servlet-thread (thread (lambda () (do-servlet page-servlet directory))))
  (define websocket-thread (thread (lambda() (websocket-listener ws-port this-thread))))
  (define client-thread '())
  (define (do-listener)
    (define received-event (thread-receive))
    (cond
      [(thread? received-event) (set! client-thread received-event)]
      [(thread? client-thread)
      (displayln (format "listener got event: ~s" received-event))
      (thread-send client-thread received-event)
      (set! page-content (reload-index index))])
      (system command) ; execute command, since change happened
    (do-listener))
  (do-listener))

(start-listener (index-file) (watched-directory) command-to-run)
