import raylib, math, random

type
  BoundingBox3D* = object
    min*: Vector3
    max*: Vector3

proc newBoundingBox*(center: Vector3, size: Vector3): BoundingBox3D =
  result.min = Vector3(
    x: center.x - size.x / 2,
    y: center.y - size.y / 2,
    z: center.z - size.z / 2
  )
  result.max = Vector3(
    x: center.x + size.x / 2,
    y: center.y + size.y / 2,
    z: center.z + size.z / 2
  )

proc checkCollision*(point: Vector3, box: BoundingBox3D): bool =
  return point.x >= box.min.x and point.x <= box.max.x and
         point.y >= box.min.y and point.y <= box.max.y and
         point.z >= box.min.z and point.z <= box.max.z

proc lerp*(a, b, t: float): float =
  return a + (b - a) * t

proc distance2D*(a, b: Vector3): float =
  let dx = a.x - b.x
  let dz = a.z - b.z
  return sqrt(dx * dx + dz * dz)

proc formatMoney*(amount: int): string =
  return "$" & $amount

proc clamp*(value, minVal, maxVal: float): float =
  if value < minVal: return minVal
  if value > maxVal: return maxVal
  return value

proc randomRange*(min, max: int): int =
  return min + (rand(max - min))