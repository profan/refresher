; program purpose: 
;   inject watching websocket code into html page being served, refresh served page on 
;   file-system change (or other synchronizable event, in this case just file-system)
;
;   built to make it easier to get a fast workflow with luxe primarily
;
;   requires: rfc6455 - websocket library

#lang racket/base

(require net/rfc6455)
(require 
  (prefix-in x: xml)
  (prefix-in h: html))
(require
  web-server/servlet
  web-server/servlet-env)
(require
  racket/date
  racket/cmdline
  racket/function
  racket/format
  racket/path
  racket/system)

; server variables
(define web-port 8000)
(define ws-port 8001)
(define reload-wait-time 0.1) ; seconds

; client variables
(define reconnect-wait-time 1000) ; milliseconds

; global variables
(define page-content (x:string->xexpr "<html></html>"))
(date-display-format 'rfc2822)
(x:permissive-xexprs #t)

; command line arguments config
(define index-file (make-parameter "index.html"))
(define watched-directory (make-parameter "."))
(define resource-directories (make-parameter '()))
(define watching-pattern (make-parameter #px"."))
(define open-on-start? (make-parameter #f))
(define command-to-run (command-line
    #:program "refresher"
    #:once-each
    [("-l" "--launch-browser") "Open the page in your browser automatically on startup (default is no)"
                                (open-on-start? #t)]
    [("-i" "--index-file") file
                            "HTML index file to serve."
                            (index-file file)]
    [("-d" "--directory") dir
                          "Directory to watch for changes."
                          (watched-directory dir)]
    [("-p" "--pattern") pattern
                        "Pattern to use for matching files (only used if platform supports file-watching)."
                        (watching-pattern (pregexp pattern))]
    #:multi
    [("-r" "--resource-directory") res-dir
                                   "Directories to add to use for resources."
                                   (resource-directories (cons res-dir (resource-directories)))]
    #:args (command)
    command))

; injected code
(define injected-code 
  (format "<script>

  function setUpWebSocket() {

    var host = \"ws://localhost:~a\";
    var time_between_reconnect = ~a;
    var ws = new WebSocket(host);

    ws.onopen = function(evt) {
      console.log(\"Connection established to notifier at: \" + host);
    }

    ws.onmessage = function(evt) {
      window.location.reload();
    }

    ws.onclose = function(evt) {
      setTimeout(function() {
        console.log(\"Connection lost to notifier, attempting to reconnect!\");
        setUpWebSocket();
      }, time_between_reconnect);
    }

   }

  setUpWebSocket();

  </script>" ws-port reconnect-wait-time))

(define injected-xml (x:string->xexpr injected-code))

; utility functions
(define (neq? a b)
  (not (eq? a b)))

(define (current-date->string)
  (date->string (current-date) #t))

(define (get-address protocol port)
  (format "~a://localhost:~a" protocol port))

(define (log-thing thing)
  (displayln (format "[~a] ~a" (current-date->string) thing)))

(define (inject-listener in-xml)
  (define xml-data (h:read-html-as-xml in-xml))
  (define xml-structure (x:xml->xexpr (x:element #f #f 'html '() xml-data)))
  (append xml-structure (list injected-xml)))

(define (reload-index file-name)
  (sleep reload-wait-time) ; make a retry function instead next
  (call-with-input-file file-name
    (lambda (in) (inject-listener in))))

(define (build-paths paths fallback)
  (cond
    [(and (list? paths) (neq? paths '()))
     (for/list ([p paths])
       (build-path (string->path p)))]
    [else fallback]))

(define (create-listeners dir pat)
  (define filtered-items 
    (filter (lambda (element) (regexp-match? pat element)) (in-directory dir)))
  #t
  )

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

(define (do-servlet servlet-func index dirs launch?)
  (serve/servlet servlet-func
                 #:launch-browser? launch?
                 #:servlet-path "/"
                 #:extra-files-paths
                 (build-paths dirs `(,(simple-form-path index)))))

(define (start-listener index directory res-dirs command launch-browser?)
  (define this-thread (current-thread))
  (set! page-content (reload-index index)) ; initial load of data
  (define change-thread (thread (lambda () (change-listener directory this-thread))))
  (define servlet-thread (thread (lambda () (do-servlet page-servlet index res-dirs launch-browser?))))
  (define websocket-thread (thread (lambda () (websocket-listener ws-port this-thread))))
  (define client-thread '())
  (define (do-listener last-event-time)
    (define received-event (thread-receive))
    (cond
      [(thread? received-event) (set! client-thread received-event)]
      [(and (thread? client-thread) (> (- (current-seconds) last-event-time) 5))
      (log-thing (format "listener got event: ~s" received-event))
      (system command)
      (set! page-content (reload-index index))
      (thread-send client-thread received-event)
      (do-listener (current-seconds))]); execute command, since change happened]
    (do-listener last-event-time))
  (do-listener (current-seconds)))

(log-thing (format "started refresher, web at: ~a, ws at: ~a" (get-address 'http web-port) (get-address 'ws ws-port)))
(start-listener (index-file) (watched-directory) (resource-directories) command-to-run (open-on-start?))
