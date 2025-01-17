extends RigidBody3D
<<<<<<< HEAD:assets/scripts/Holdable.gd

var Util = preload("res://assets/scripts/Util.gd")
=======
>>>>>>> finalport:addons/portals/scripts/Holdable.gd

# Amount of seconds to hold an object
const TIME_HOLD_OBJ = 0.5
# The maximum linear_velocity the object can have checked release; this exists to prevent
# the object from glitching far away during rapid player movement
const MAX_RELEASE_VELOCITY = 10.0

# The node holding the object, or `null` if it's not held
var _holder: Node3D = null
# Amount of seconds since object was held
var _time_since_held := 0.0

func dampen_vector(vec: Vector3, max_len: float) -> Vector3:
	if vec.length() > max_len:
		return vec.normalized() * max_len
	else:
		return vec


func drop() -> void:
	_holder = null

	# For some reason, it is possible for the linear_velocity to be reset when the
	# custom integrator is turned unchecked (race condition?); anyway, it is saved
	# and restored to prevent this
	var lin_vel := linear_velocity
	var ang_vel := angular_velocity

	# Dampen linear_velocity to prevent glitchy cube flailing
	lin_vel = dampen_vector(lin_vel, MAX_RELEASE_VELOCITY)
	ang_vel = dampen_vector(ang_vel, MAX_RELEASE_VELOCITY)
	linear_velocity = lin_vel
	angular_velocity = ang_vel

	custom_integrator = false


func hold(holder: Node3D) -> void:
	_holder = holder
	_time_since_held = 0.0
	custom_integrator = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _holder == null:
		return

	var delta := state.step

	# Update interpolation timer
	_time_since_held += delta
	_time_since_held = clamp(_time_since_held, 0.0, TIME_HOLD_OBJ)
	var interp := _time_since_held / TIME_HOLD_OBJ

	# Compute the current, target, and next positions; the target position is
	# at a fixed location relative to the player head, while the position in
	# the next frame interpolates between the target and original position
	var pos_cur := get_global_transform()
	var pos_target := _holder.get_global_transform()
	var pos_next := pos_cur.interpolate_with(pos_target, interp)

	# Calculate amount cube needs to rotate
	var rot := (pos_next * pos_cur.inverse()).basis \
		super.get_rotation_quaternion().get_euler()

	# Actually move the object
	state.linear_velocity = (pos_next.origin - pos_cur.origin) / delta
	state.angular_velocity = rot / delta

	# Hack to prevent the cube from clipping through walls; basically, we
	# dampen the linear_velocity based checked collision normals
	for i in range(state.get_contact_count()):
		var norm := state.get_contact_local_normal(i)
		var vel := state.linear_velocity
		var dir := norm.cross(vel).cross(norm).normalized()
		vel = vel.dot(dir) * dir
		state.linear_velocity = vel
