class_name Genome

var genes = []


class Gene:
  var id: int setget , get_id

  func _init(_id):
    id = _id

  func get_id():
    return id



class InputNode:
  extends Gene

  var name
  var outgoing_link_ids
  var outgoing_links = []

  func _init(_id, _name="", _outgoing_link_ids=[]).(_id):
    name = _name
    outgoing_link_ids = _outgoing_link_ids

  func add_outgoing_link(link: Link):
    outgoing_links.append(link)


class HiddenNode:
  extends Gene

  var name
  var incoming_link_ids
  var outgoing_link_ids
  var incoming_links = []
  var outgoing_links = []

  func _init(_id, _name="",_incoming_link_ids=[], _outgoing_link_ids=[]).(_id):
    name = _name
    incoming_link_ids = _incoming_link_ids
    outgoing_link_ids = _outgoing_link_ids

  func add_incoming_link(link: Link):
    incoming_links.append(link)

  func add_outgoing_link(link: Link):
    outgoing_links.append(link)



class OutputNode:
  extends Gene

  var name
  var incoming_link_ids
  var incoming_links = []

  func _init(_id, _name="", _incoming_link_ids=[]).(_id):
    name = _name
    incoming_link_ids = _incoming_link_ids

  func add_incoming_link(link: Link):
    incoming_links.append(link)


class Link:
  var id: int
  var source_node: Gene
  var target_node: Gene
  var weight: float
  var source_id: int
  var target_id: int
  var is_enabled: bool

  func _init(_id, _source_node: Gene, _target_node: Gene, _weight,
      _source_id, _target_id, _is_enabled: bool):
    id = _id
    source_node = _source_node
    target_node = _target_node
    weight = _weight
    source_id = _source_id
    target_id = _target_id
    is_enabled = _is_enabled

    source_node.add_outgoing_link(self)
    target_node.add_incoming_link(self)
