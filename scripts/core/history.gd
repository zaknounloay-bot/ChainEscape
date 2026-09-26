class_name History
extends RefCounted
## Generic undo stack of state snapshots.
##
## Callers push an opaque state (any Variant) *before* mutating the game and
## pop it back to undo. No per-action undo logic is needed: whatever the game
## puts in the snapshot is exactly what comes back.

var _stack: Array = []


func push(state) -> void:
	_stack.append(state)


func pop():
	return _stack.pop_back()


func can_undo() -> bool:
	return not _stack.is_empty()


func clear() -> void:
	_stack.clear()


func size() -> int:
	return _stack.size()
