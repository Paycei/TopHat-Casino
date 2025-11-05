import raylib, utils
import machines/roulette, machines/slots, machines/blackjack

type
  MachineType* = enum
    RouletteM, SlotsM, BlackjackM
  
  Machine* = object
    position*: Vector3
    machineType*: MachineType
    bounds*: BoundingBox3D
  
  Casino* = ref object
    machines*: seq[Machine]
    roulette*: Roulette
    slots*: Slots
    blackjack*: Blackjack

proc newCasino*(): Casino =
  result = Casino()
  result.machines = @[]
  let roulettePos = Vector3(x: -5.0, y: 0.0, z: 0.0)
  result.roulette = newRoulette(roulettePos)
  result.machines.add(Machine(
    position: roulettePos,
    machineType: RouletteM,
    bounds: newBoundingBox(roulettePos, Vector3(x: 3.0, y: 3.0, z: 3.0))
  ))
  let slotsPos = Vector3(x: 5.0, y: 0.0, z: 0.0)
  result.slots = newSlots(slotsPos)
  result.machines.add(Machine(
    position: slotsPos,
    machineType: SlotsM,
    bounds: newBoundingBox(slotsPos, Vector3(x: 3.0, y: 3.0, z: 3.0))
  ))
  let blackjackPos = Vector3(x: 0.0, y: 0.0, z: -6.0)
  result.blackjack = newBlackjack(blackjackPos)
  result.machines.add(Machine(
    position: blackjackPos,
    machineType: BlackjackM,
    bounds: newBoundingBox(blackjackPos, Vector3(x: 4.0, y: 3.0, z: 3.0))
  ))

proc drawEnvironment*(casino: Casino) =
  drawPlane(Vector3(x: 0, y: 0, z: 0), Vector2(x: 30, y: 30), Maroon)
  for x in -15..15:
    for z in -15..15:
      if (x + z) mod 2 == 0:
        drawCube(
          Vector3(x: x.float, y: -0.01, z: z.float),
          1.0, 0.01, 1.0,
          DarkBrown
        )
  drawCube(Vector3(x: 0, y: 2.5, z: -10), 30, 5, 0.5, DarkGray)
  drawCube(Vector3(x: 0, y: 2.5, z: 10), 30, 5, 0.5, DarkGray)
  drawCube(Vector3(x: -15, y: 2.5, z: 0), 0.5, 5, 20, DarkGray)
  drawCube(Vector3(x: 15, y: 2.5, z: 0), 0.5, 5, 20, DarkGray)
  for x in [-8, 0, 8]:
    for z in [-6, 0, 6]:
      drawSphere(
        Vector3(x: x.float, y: 4.8, z: z.float),
        0.3, Yellow
      )
  let pillarPositions = [
    Vector3(x: -10, y: 2.5, z: -7),
    Vector3(x: 10, y: 2.5, z: -7),
    Vector3(x: -10, y: 2.5, z: 7),
    Vector3(x: 10, y: 2.5, z: 7)
  ]
  
  for pos in pillarPositions:
    drawCube(pos, 0.8, 5, 0.8, Gold)

proc drawMachines*(casino: Casino) =
  casino.roulette.draw3D()
  casino.slots.draw3D()
  casino.blackjack.draw3D()
  for machine in casino.machines:
    let labelPos = Vector3(
      x: machine.position.x,
      y: machine.position.y + 3.0,
      z: machine.position.z
    )

    drawCube(labelPos, 2.0, 0.3, 0.1, Gold)

proc update*(casino: Casino, deltaTime: float) =
  casino.roulette.update(deltaTime)
  casino.slots.update(deltaTime)

proc getNearestMachine*(casino: Casino, playerPos: Vector3): tuple[machine: Machine, distance: float] =
  var nearest: Machine
  var minDistance = 999999.0
  var found = false
  
  for machine in casino.machines:
    let dist = distance2D(playerPos, machine.position)
    if dist < minDistance:
      minDistance = dist
      nearest = machine
      found = true
  
  if found:
    return (nearest, minDistance)
  else:
    return (nearest, minDistance)