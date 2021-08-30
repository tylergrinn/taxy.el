;;; taxy-magit-section.el ---                        -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Free Software Foundation, Inc.

;; Author: Adam Porter <adam@alphapapa.net>
;; Maintainer: Adam Porter <adam@alphapapa.net>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

;;;; Requirements

(require 'taxy)
(require 'magit-section)

;;;; Variables

(defvar taxy-magit-section-indent 2
  "Default indentation per level.")

;;;; Customization


;;;; Structs

(cl-defstruct (taxy-magit-section (:include taxy))
  ;; This struct is not required to be used for taxys passed to
  ;; `taxy-magit-section-insert', but it allows a visibility function
  ;; to be specified to override the default for it.
  (visibility-fn #'taxy-magit-section-visibility)
  (indent 2)
  format-fn)

;;;; Commands


;;;; Functions

(cl-defun taxy-magit-section-insert (taxy &key (items 'first))
  "Insert a `magit-section' for TAXY into current buffer.
If ITEMS is `first', insert a taxy's items before its
descendant taxys; if `last', insert them after descendants."
  (let* ((depth 0)
         (magit-section-set-visibility-hook (cons #'taxy-magit-section-visibility magit-section-set-visibility-hook)))
    (cl-labels ((insert-item
                 (item format-fn indent)
                 (magit-insert-section (magit-section item)
                   (magit-insert-section-body
		     ;; This is a tedious way to give the indent
		     ;; string the same text properties as the start
		     ;; of the formatted string, but no matter where I
		     ;; left point after using `insert-and-inherit',
		     ;; something was wrong about the properties, and
		     ;; `magit-section' didn't navigate the sections
		     ;; properly anymore.
		     (let* ((formatted (funcall format-fn item))
			    (indent (make-string (+ 2 (* depth indent)) ? )))
		       (add-text-properties 0 (length indent)
					    (text-properties-at 0 formatted)
					    indent)
		       (insert indent formatted "\n")))))
                (insert-taxy
                 (taxy) (let ((magit-section-set-visibility-hook magit-section-set-visibility-hook)
                              (format-fn (cl-typecase taxy
                                           (taxy-magit-section
                                            (taxy-magit-section-format-fn taxy))
                                           (t (lambda (o) (format "%s" o))))))
                          (cl-typecase taxy
                            (taxy-magit-section
                             (when (taxy-magit-section-visibility-fn taxy)
                               (push (taxy-magit-section-visibility-fn taxy) magit-section-set-visibility-hook))))
                          (magit-insert-section (magit-section taxy)
                            (magit-insert-heading
                              (make-string (* depth taxy-magit-section-indent) ? )
                              (propertize (taxy-name taxy) 'face 'magit-section-heading)
                              (format " (%s%s)"
                                      (if (taxy-description taxy)
                                          (concat (taxy-description taxy) " ")
                                        "")
                                      (taxy-size taxy)))
                            (magit-insert-section-body
                              (when (eq 'first items)
                                (dolist (item (taxy-items taxy))
                                  (insert-item item format-fn (taxy-magit-section-indent taxy))))
                              (cl-incf depth)
                              (mapc #'insert-taxy (taxy-taxys taxy))
                              (cl-decf depth)
                              (when (eq 'last items)
                                (dolist (item (taxy-items taxy))
                                  (insert-item item format-fn (taxy-magit-section-indent taxy)))))))))
      (magit-insert-section (magit-section)
        (insert-taxy taxy)))))

(cl-defun taxy-magit-section-pp (taxy &key (items 'first))
  "Pretty-print TAXY into a buffer with `magit-section' and show it."
  (with-current-buffer (get-buffer-create "*taxy-magit-section-pp*")
    (magit-section-mode)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (taxy-magit-section-insert taxy :items items))
    (pop-to-buffer (current-buffer))))

(defun taxy-magit-section-visibility (section)
  "Show SECTION if its taxy is non-empty.
Default visibility function for
`magit-section-set-visibility-hook'."
  (pcase (oref section value)
    ((and (pred taxy-p) taxy)
     (pcase (taxy-size taxy)
       (0 'hide)
       (_ 'show)))
    (_ nil)))

;;;; Footer

(provide 'taxy-magit-section)

;;; taxy-magit-section.el ends here
