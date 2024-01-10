class_name Genome

const MUTATION_RATE = 0.8
const WEIGHT_SHIFT_RATE = 0.9
const EXPECTED_MUTATED_GENE_RATE = 0.1
const MUTATION_STANDARD_DEVIATION = 2.0
const ORIGINAL_WEIGHT_VALUE_LIMIT = 2.0
const ADD_LINK_RATE = 0.3

var input_nodes
var hidden_nodes
var output_nodes
var links
var fitness

var random = RandomNumberGenerator.new()


func _init(_input_nodes=[], _hidden_nodes=[], _output_nodes=[],
    _links=[], _fitness=0):
  input_nodes = _input_nodes
  hidden_nodes = _hidden_nodes
  output_nodes = _output_nodes
  links = _links
  fitness = _fitness


func mutate():
  random.randomize()
  if random.randf() < MUTATION_RATE:
    for link in links:
      # Shift weights
      if random.randf() < WEIGHT_SHIFT_RATE:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randfn(link["weight"], MUTATION_STANDARD_DEVIATION)
      # Change weights randomly
      else:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT)
      # Disable link
      if random.randf() < EXPECTED_MUTATED_GENE_RATE / 2:
        link["is_enabled"] = !link["is_enabled"]
    # Add a link
    if random.randf() < ADD_LINK_RATE:
      var source_nodes = input_nodes + hidden_nodes
      var source_node = source_nodes[random.randi_range(0, source_nodes.size() - 1)]
      var target_node = choose_target_node(source_node)
      if target_node != null:
        var new_id = generate_UID()
        var new_link = Link.new(new_id, source_node, target_node,
            random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT),
            source_node.id, target_node.id, true)
        links.append(new_link)
        source_node.add_outgoing_link(new_link)
        target_node.add_incoming_link(new_link)



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
    outgoing_link_ids.append(link.id)


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
    incoming_link_ids.append(link.id)

  func add_outgoing_link(link: Link):
    outgoing_links.append(link)
    outgoing_link_ids.append(link.id)



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
    incoming_link_ids.append(link.id)


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
