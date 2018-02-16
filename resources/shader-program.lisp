#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defclass shader-program (gl-resource)
  ((uniform-map :initform (make-hash-table :test 'equal) :accessor uniform-map)
   (shaders :initarg :shaders :accessor shaders))
  (:default-initargs
   :shaders (error "SHADERS required.")))

(defun check-shader-compatibility (shaders)
  (loop with table = (make-hash-table :test 'eql)
        for shader in shaders
        do (if (gethash (shader-type shader) table)
               (error "Cannot compile two shaders of the same type into a single program~%  ~a~%  ~a"
                      (gethash (shader-type shader) table) shader)
               (setf (gethash (shader-type shader) table) shader))
        finally (return shaders)))

(defmethod destructor ((program shader-program))
  (let ((prog (gl-name program)))
    (lambda () (gl:delete-program prog))))

(defmethod allocate ((program shader-program))
  (let ((shaders (shaders program)))
    (check-shader-compatibility shaders)
    (let ((prog (gl:create-program)))
      (with-cleanup-on-failure (gl:delete-program prog)
        (dolist (shader shaders)
          (check-allocated shader)
          (gl:attach-shader prog (gl-name shader)))
        (gl:link-program prog)
        (dolist (shader shaders)
          (gl:detach-shader prog (gl-name shader)))
        (unless (gl:get-program prog :link-status)
          (error "Failed to link ~a: ~%~a"
                 program (gl:get-program-info-log prog)))
        (v:debug :trial.asset "Linked ~a with ~a." program shaders)
        (setf (data-pointer program) prog)))))

(defmethod deallocate :after ((program shader-program))
  (clrhash (uniform-map program)))

(declaim (inline %set-uniform))
(defun %set-uniform (location data)
  (declare (optimize speed))
  (declare (type (signed-byte 32) location))
  (etypecase data
    (vec4 (%gl:uniform-4f location (vx data) (vy data) (vz data) (vw data)))
    (vec3 (%gl:uniform-3f location (vx data) (vy data) (vz data)))
    (vec2 (%gl:uniform-2f location (vx data) (vy data)))
    (mat4 #+sbcl
          (let ((data (marr4 data)))
            (sb-sys:with-pinned-objects (data)
              (%gl:uniform-matrix-4fv location 1 T (sb-sys:vector-sap data))))
          #-sbcl
          (gl:uniform-matrix-4fv location (marr4 data)))
    (mat3 #+sbcl
          (let ((data (marr3 data)))
            (sb-sys:with-pinned-objects (data)
              (%gl:uniform-matrix-3fv location 1 T (sb-sys:vector-sap data))))
          #-sbcl
          (gl:uniform-matrix-3fv location (marr3 data)))
    (mat2 #+sbcl
          (let ((data (marr2 data)))
            (sb-sys:with-pinned-objects (data)
              (%gl:uniform-matrix-2fv location 1 T (sb-sys:vector-sap data))))
          #-sbcl
          (gl:uniform-matrix-2fv location (marr2 data)))
    (single-float (%gl:uniform-1f location data))
    (double-float (%gl:uniform-1d location data))
    (fixnum (%gl:uniform-1i location data))
    (matn (ecase (mrows data)
            (2 (ecase (mcols data)
                 (3 (gl:uniform-matrix-2x3-fv location (marrn data)))
                 (4 (gl:uniform-matrix-2x4-fv location (marrn data)))))
            (3 (ecase (mcols data)
                 (2 (gl:uniform-matrix-3x2-fv location (marrn data)))
                 (4 (gl:uniform-matrix-3x4-fv location (marrn data)))))
            (4 (ecase (mcols data)
                 (2 (gl:uniform-matrix-4x2-fv location (marrn data)))
                 (3 (gl:uniform-matrix-4x3-fv location (marrn data)))))))))

(defun (setf uniform) (data asset name)
  (declare (optimize speed))
  (let* ((name (etypecase name
                 (string name)
                 (symbol (symbol->c-name name))))
         (location (or (gethash name (uniform-map asset))
                       (setf (gethash name (uniform-map asset))
                             (gl:get-uniform-location (gl-name asset) name)))))
    (%set-uniform location data)))

(define-compiler-macro (setf uniform) (&whole whole &environment env data asset name)
  (cond ((constantp name env)
         (let ((nameg (gensym "NAME")) (assetg (gensym "ASSET")))
           `(let ((,nameg (load-time-value
                           (etypecase ,name
                             (string ,name)
                             (symbol (symbol->c-name ,name)))))
                  (,assetg ,asset))
              (%set-uniform (or (gethash ,nameg (uniform-map ,assetg))
                                (setf (gethash ,nameg (uniform-map ,assetg))
                                      (gl:get-uniform-location (gl-name ,assetg) ,nameg)))
                            ,data))))
        (T
         whole)))
