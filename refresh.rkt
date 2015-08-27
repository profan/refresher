; program purpose: 
;   inject watching websocket code into html page being served, refresh served page on 
;   file-system change (or other synchronizable event, in this case just file-system)
;
;   built to make it easier to get a fast workflow with luxe primarily
;
;   requires: rfc6455 - websocket library

#lang racket

(require xml)
(require net/rfc6455)
(require racket/cmdline)
(require web-server/servlet
         web-server/servlet-env)

; command line arguments config
(define index-file (make-parameter "index.html"))
(define watched-directory (make-parameter "."))

(command-line
    #:program "refresher"
    #:once-each
    [("-i" "--index-file") file
                            "HTML index file to serve."
                            (index-file file)]
    [("-d" "--directory") dir
                          "Directory to watch for changes."
                          (watched-directory dir)])

(define (inject-listener in-xml)
  (define read-xml (read-xml in-xml))
  (displayln read-xml))

(define (reload-index file-name)
  (call-with-input-file file-name)
    (lambda (in) ((inject-listener in))))

; listeners
(define (change-listener directory target-thread)
  (define change-event (filesystem-change-evt directory))
  (define change (sync change-event)) ; sync on change - do things when shit happens!
  (thread-send target-thread #t)
  (change-listener directory target-thread))

(define (listen index directory)

  #t)

(define (start-listener index directory)
  (define this-thread (current-thread))
  (define change-thread (thread (lambda () (change-listener directory this-thread))))
  (define (do-listener)
    (define received-event (thread-receive))
    (displayln (format "event: ~s" received-event))
    (do-listener))
  (do-listener))

(start-listener (index-file) (watched-directory))
