(defun org-to-html (resources)
  (interactive)

  (let ((inhibit-message t))
    (load "~/.emacs"))

  (setq org-html-htmlize-output-type "css")
  (setq org-html-head (format "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\" />" (concat resources "/index.css")))

  (org-mode)
  ;; Cleanup default options; these should be configurable in preferences.
  (org-html-export-as-html nil nil nil nil '(:html-postamble nil :section-numbers nil :with-toc nil))
  (princ "<!-- org-html-export-as-html --!>\n")
  (princ (buffer-string)))
