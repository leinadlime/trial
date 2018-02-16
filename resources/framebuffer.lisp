#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defclass framebuffer (gl-resource)
  ((attachments :initarg :attachments :accessor attachments))
  (:default-initargs
   :attachments (error "ATTACHMENTS required.")))

(defmethod destructor ((framebuffer framebuffer))
  (let ((fbo (gl-name framebuffer)))
    (lambda () (gl:delete-framebuffers (list fbo)))))

(defmethod allocate ((framebuffer framebuffer))
  (let ((fbo (gl:gen-framebuffer)))
    (with-cleanup-on-failure (gl:delete-framebuffers (list fbo))
      (gl:bind-framebuffer :framebuffer fbo)
      (unwind-protect
           (dolist (attachment (attachments framebuffer))
             (destructuring-bind (attachment texture &key (level 0) layer &allow-other-keys) attachment
               (check-framebuffer-attachment attachment)
               (check-type texture texture)
               (check-allocated texture)
               (v:debug :trial.framebuffer "Attaching ~a as ~a to ~a." texture attachment framebuffer)
               (if layer
                   (%gl:framebuffer-texture-layer :framebuffer attachment (gl-name texture) level layer)
                   (%gl:framebuffer-texture :framebuffer attachment (gl-name texture) level))
               (let ((completeness (gl:check-framebuffer-status :framebuffer)))
                 (unless (find completeness '(:framebuffer-complete :framebuffer-complete-oes))
                   (error "Failed to attach ~a as ~s to ~a: ~s"
                          texture attachment framebuffer completeness)))))
        (gl:bind-framebuffer :framebuffer 0)
        (setf (data-pointer framebuffer) fbo)))))

(defmethod resize ((framebuffer framebuffer) width height)
  (dolist (attachment (attachments framebuffer))
    (resize (second attachment) width height)))
