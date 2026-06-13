extends RefCounted


static func try_intercept(candidate: Node, attack_profile: Resource, source: Node = null) -> Node:
	if candidate == null or attack_profile == null:
		return null
	if not bool(attack_profile.get("can_intercept_projectile")):
		return null

	var current := candidate
	while current != null:
		if _try_intercept_node(current, attack_profile, source):
			return current
		current = current.get_parent()
	return null


static func attack_tags(attack_profile: Resource) -> Array:
	var tags := []
	if attack_profile == null:
		return tags

	var configured_tags: Variant = attack_profile.get("intercept_tags")
	if configured_tags is PackedStringArray:
		for tag in configured_tags:
			tags.append(String(tag))
	elif configured_tags is Array:
		for tag in configured_tags:
			tags.append(String(tag))
	return tags


static func has_matching_tag(attack_tags: Array, required_tags: Array) -> bool:
	if required_tags.is_empty():
		return true
	for tag in attack_tags:
		if tag in required_tags:
			return true
	return false


static func required_tags_from(target: Node) -> Array:
	var tags := []
	if target == null or not target.has_method("get_intercept_require_tags"):
		return tags

	var required_tags: Variant = target.get_intercept_require_tags()
	if required_tags is PackedStringArray:
		for tag in required_tags:
			tags.append(String(tag))
	elif required_tags is Array:
		for tag in required_tags:
			tags.append(String(tag))
	return tags


static func _try_intercept_node(target: Node, attack_profile: Resource, source: Node) -> bool:
	if not target.has_method("can_be_intercepted_by") or not target.has_method("intercept_projectile"):
		return false
	if not bool(target.can_be_intercepted_by(attack_profile, source)):
		return false
	return bool(target.intercept_projectile(attack_profile, source))
