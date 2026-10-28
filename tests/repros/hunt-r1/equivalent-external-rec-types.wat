(module
  (type $a (struct))
  (type $b (struct))
  (rec
    (type $x (struct (field (ref $a)) (field (ref $y))))
    (type $y (struct (field (ref $x)))))
  (rec
    (type $u (struct (field (ref $b)) (field (ref $v))))
    (type $v (struct (field (ref $u)))))
  (func (param (ref $x)) (result (ref $u)) local.get 0))
