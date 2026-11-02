; extends

; Everything outside the template tags is HTML, with its own CSS and JavaScript
((content) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined))
