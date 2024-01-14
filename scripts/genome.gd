class_name Genome

const MUTATION_RATE = 0.8
const WEIGHT_SHIFT_RATE = 0.9
const EXPECTED_MUTATED_GENE_RATE = 0.1
const MUTATION_STANDARD_DEVIATION = 2.0
const ORIGINAL_WEIGHT_VALUE_LIMIT = 2.0
const ADD_LINK_RATE = 0.3
const ADD_NODE_RATE = 0.25

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


func link_already_exists(source_node, target_node):
  if target_node.incoming_links != null: # Because it can be an input node in the recursion
    for link in target_node.incoming_links:
      if link.source_id == source_node.id:
        return true
  return false

func is_circular_loop(source_node, target_node):
  for link in links:
    if link.source_id == target_node.id && link.target_id == source_node.id:
      return true
    
  if target_node.outgoing_links != null: # Because it can be an output node as a candidate target
    for outlink in target_node.outgoing_links:

      # In order to recurse we first have to find the target node of the target_node when it is not the source node
      var candidate_target_nodes = hidden_nodes
      var target_of_the_target_node
      for node in candidate_target_nodes:
        if node.id == outlink.target_id:
          target_of_the_target_node = node # this can be null because the target of the link is an output node
      if target_of_the_target_node != null && is_circular_loop(source_node, target_of_the_target_node):
        return true
  return false

func choose_target_node(source_node): # Needed for mutate()
  var candidate_nodes = hidden_nodes + output_nodes
  var unlinked_nodes = []
  for target_node in candidate_nodes:
    var is_node_linked := false
    if target_node.id == source_node.id || \
        is_circular_loop(source_node, target_node) || \
        link_already_exists(source_node, target_node):
      is_node_linked = true
    if !is_node_linked:
      unlinked_nodes.append(target_node)
  if !unlinked_nodes.empty():
    var final_target_node
    while final_target_node == null:
      for unlinked_node in unlinked_nodes:
        if random.randf() < float(1.0 / unlinked_nodes.size()):
          final_target_node = unlinked_node
          break
    return final_target_node
  else:
    return null

# Mutate this specific genome
func mutate():
  random.randomize()
  if random.randf() < MUTATION_RATE:
    for link in links:
      # Shift weights
      if random.randf() < WEIGHT_SHIFT_RATE:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randfn(link.weight, MUTATION_STANDARD_DEVIATION)
      # Change weights randomly
      else:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT)
      # Disable link
      if random.randf() < EXPECTED_MUTATED_GENE_RATE / 3:
        link["is_enabled"] = !link["is_enabled"]
    # Add a link
    if random.randf() < ADD_LINK_RATE:
      var source_nodes = input_nodes + hidden_nodes
      var source_node = source_nodes[random.randi_range(0, source_nodes.size() - 1)]
      var target_node = choose_target_node(source_node)
      if target_node != null:
        var new_id = Main.generate_UID()
        var new_link = Link.new(new_id, source_node, target_node,
            random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT),
            source_node.id, target_node.id, true)
        links.append(new_link)
        source_node.add_outgoing_link(new_link)
        target_node.add_incoming_link(new_link)

    # Add a new node and break the link
    if links.size() == 0:
      return # cannot break a link if there isn't one
    if random.randf() < ADD_NODE_RATE:
      # find a random link to break
      var link_to_break
      while link_to_break == null:
        for genome_link in links:
          if random.randf() < links.size():
            link_to_break = genome_link
            break
      link_to_break.is_enabled = false # original link disabled
      # find the source and target nodes of the original link that is about to break
      var original_source_node
      for genome_source_node in input_nodes + hidden_nodes:
        if link_to_break.source_id == genome_source_node.id:
          original_source_node = genome_source_node
      var original_target_node
      for genome_target_node in output_nodes + hidden_nodes:
        if link_to_break.target_id == genome_target_node.id:
          original_target_node = genome_target_node
      # construct the new hidden node and append it to hidden_nodes
      var new_hidden_node = HiddenNode.new(Main.generate_UID(), [], [])
      hidden_nodes.append(new_hidden_node)
      # create the new links for the new hidden node
      var link_a = Link.new(Main.generate_UID(),
          original_source_node.id,
          new_hidden_node.id,
          1.0, original_source_node, new_hidden_node, true)
      var link_b = Link.new(Main.generate_UID(),
          new_hidden_node.id,
          original_target_node.id,
          1.0, new_hidden_node, original_target_node, true)
      links.append(link_a)
      links.append(link_b)
      new_hidden_node.add_incoming_link(link_a)
      new_hidden_node.add_outgoing_link(link_b)
      original_source_node.add_outgoing_link(link_a)
      original_target_node.add_incoming_link(link_b)



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
