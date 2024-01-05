class_name NeuralNetwork

const INPUT_INCREMENT := 0.01
const NO_ID := -1
const THRESHOLD := 1.0
const E = 2.7182

var random = RandomNumberGenerator.new()
var input_layer = [] 
var output_layer = [] 
var hidden_layer = [] 
var links = []

var genome
var starting_link_id: int

func _init(_genome, _starting_link_id=0):
  # Warning: passed by reference
  genome = _genome
  starting_link_id = _starting_link_id
  random.randomize()

  # Create nodes according to the genome (made in agent.gd)
  for input_node_gene in genome["input_nodes"]:
    var i_node = InputNode.new(input_node_gene["id"], input_node_gene["name"])
    input_layer.append(i_node)

  for hidden_node_gene in genome["hidden_nodes"]:
    var h_node = HiddenNode.new(hidden_node_gene["id"])
    hidden_layer.append(h_node)

  for output_node_gene in genome["output_nodes"]:
    var o_node = OutputNode.new(output_node_gene["id"], output_node_gene["name"])
    output_layer.append(o_node)

  var all_nodes = input_layer + hidden_layer + output_layer

  # Create the links between the nodes
  if !genome.has("links"):
    genome["links"] = []
    # connect_nn_layers(input_layer, output_layer)
  else:
    # Use genome to connect the links
    for link in genome["links"]:
      var source_node
      var target_node
      for node in all_nodes:
        var nid = node.id
        if nid == link["source_id"]:
          source_node = node
        elif nid == link["target_id"]:
          target_node = node
      if (source_node != null) && (target_node != null):
        var link_instance = Link.new(link["id"], source_node, target_node,
            link["weight"], link["bias"], link["source_id"],
            link["target_id"], true)
        links.append(link_instance)


func connect_nn_layers(source_layer, target_layer):
  var i := starting_link_id
  for s_node in source_layer:
    for t_node in target_layer:
      var new_link = Link.new(i, s_node, t_node,
          random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0),
          s_node.id, t_node.id, true)
      # Main.add_UID_in_used(i)
      if i > Main.max_id_used:
        Main.generate_UID()
      i += 1
      links.append(new_link)
      genome["links"].append({"id": new_link.id,"bias": new_link.bias,
          "weight": new_link.weight, "source_id": new_link.source_node.id,
          "target_id": new_link.target_node.id, "is_enabled": true})
      # add incoming_link_ids and outgoing_link_ids to the nodes involved
      var all_genome_nodes = genome["input_nodes"] \
          + genome["hidden_nodes"] \
          + genome["output_nodes"]
      for _genome_node in all_genome_nodes:
        if _genome_node["id"] == new_link.source_node.id:
          _genome_node["outgoing_link_ids"].append(new_link.id)
        elif _genome_node["id"] == new_link.target_node.id:
          _genome_node["incoming_link_ids"].append(new_link.id)



func set_input(input_dict: Dictionary):
  for node in input_layer:
    node.set_value(input_dict[node.get_name()])


func get_output() -> Dictionary:
  var output_dict = {}
  for node in output_layer:
    var node_name = node.get_name()
    output_dict[node_name] = node.get_value()

  return output_dict



class NNNode:
  var name: String setget ,get_name
  var id: int setget , get_id


  func _init(_id, _name=""):
    name = _name
    id = _id


  func get_name():
    return name

  func get_id():
    return id

  func _relu(val):
    return 0 if val <= 0 else val

  func _sigmoid(val):
    return 1 / (1 + pow(E, -val))

  func _tanh(val):
    return (2.0 / (1.0 + pow(E, -2.0 * val))) - 1.0



class InputNode:
  extends NNNode

  var value: float setget set_value, get_value
  var outgoing_links = []

  func _init(_id, _name, _value=randf()).(_id, _name):
    value = _value 

  func set_value(_value):
    value = _value

  func get_value():
    return value

  func add_outgoing_link(link: Link):
    outgoing_links.append(link)



class OutputNode:
  extends NNNode

  var incoming_links = []
  var value: float


  func _init(_id, _name="", _value=randf()).(_id, _name):
    name = _name
    value = _value


  func get_value():
    var _value := 0.0
    for link in incoming_links:
      if link.is_enabled:
        _value += link.get_value()
    return _value


  func add_incoming_link(link: Link):
    incoming_links.append(link)


  func get_normalized_threshold():
    # return (incoming_links.size() / 2.0) as float
    return THRESHOLD



class HiddenNode:
  extends NNNode

  var incoming_links = []
  var outgoing_links = []
  var value: float
  # var is_enabled: bool


  func _init(_id, _name="", _value=randf()).(_id, _name):
    value = _value
    name = _name

  func get_value():
    var _value := 0.0
    for link in incoming_links:
      if link.is_enabled:
        _value += link.get_value()
    return _value


  func add_incoming_link(link: Link):
    incoming_links.append(link)


  func add_outgoing_link(link: Link):
    outgoing_links.append(link)



class Link:
  var id: int
  var source_node: NNNode
  var target_node: NNNode
  var weight: float
  var bias: float
  var source_id: int
  var target_id: int
  var is_enabled: bool


  func _init(_id, _source_node: NNNode, _target_node: NNNode, _weight, _bias,
      _source_id, _target_id, _is_enabled: bool):
    if _id == NO_ID:
      id = Main.generate_UID()
    else:
      id = _id
    source_node = _source_node
    target_node = _target_node
    weight = _weight
    bias = _bias
    source_id = _source_id
    target_id = _target_id
    is_enabled = _is_enabled

    source_node.add_outgoing_link(self)
    target_node.add_incoming_link(self)


  func get_value():
    var val = source_node.get_value()
    # print("Val: %s, Weight: %s, Bias: %s" % [val, weight, bias])
    return (val * weight) + bias

