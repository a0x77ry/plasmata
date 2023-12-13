class_name NeuralNetwork

const INPUT_INCREMENT := 0.01
const NO_ID := -1
const THRESHOLD := 1.0

var random = RandomNumberGenerator.new()
var input_layer = [] 
var output_layer = [] 
var hidden_layer_1 = [] 
var links = []

var genome

func _init(_genome):
  # Warning: passed by reference
  genome = _genome
  random.randomize()

  # Create nodes according to the genome (made in agent.gd)
  for input_node_gene in genome["input_nodes"]:
    var i_node = InputNode.new(input_node_gene["id"], input_node_gene["name"])
    input_layer.append(i_node)

  for hidden_node_1_gene in genome["hidden_nodes_1"]:
    var h1_node = HiddenNode.new(hidden_node_1_gene["id"])
    hidden_layer_1.append(h1_node)

  for output_node_gene in genome["output_nodes"]:
    var o_node = OutputNode.new(output_node_gene["id"], output_node_gene["name"])
    output_layer.append(o_node)

  var all_nodes = input_layer + hidden_layer_1 + output_layer

  # Create the links between the nodes
  if !genome.has("links"):
    genome["links"] = []
    connect_nn_layers(input_layer, hidden_layer_1)
    connect_nn_layers(hidden_layer_1, output_layer)
  else:
    # Use genome to connect the links
    for link in genome["links"]:
      var source_node
      var target_node
      for node in all_nodes:
        var nid = node.id
        if nid == link["from_id"]:
          source_node = node
        elif nid == link["to_id"]:
          target_node = node
      if (source_node != null) && (target_node != null):
        var link_instance = Link.new(link["id"], source_node, target_node, link["weight"])
        links.append(link_instance)


func connect_nn_layers(source_layer, target_layer):
  for s_node in source_layer:
    for t_node in target_layer:
      var new_link = Link.new(NO_ID, s_node, t_node, random.randf_range(-1.0, 1.0))
      links.append(new_link)
      genome["links"].append({"id": new_link.id,
          "weight": new_link.weight, "from_id": new_link.source_node.id,
          "to_id": new_link.target_node.id})


func set_input(input_dict: Dictionary):
  for node in input_layer:
    node.set_value(input_dict[node.get_name()])


func get_output() -> Dictionary:
  var output_dict = {}
  for node in output_layer:
    var node_name = node.get_name()
    output_dict[node_name] = node.get_value()
    output_dict[node_name + "_threshold"] = node.get_normalized_threshold()

  # print("Output dict: %s" % output_dict)
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
    # return 0 if value <= 0 else value
    return val



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
      _value += link.get_value()
    return _relu(_value)


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


  func _init(_id, _name="", _value=randf()).(_id, _name):
    value = _value
    name = _name


  func get_value():
    var _value := 0.0
    for link in incoming_links:
      _value += link.get_value()
    return _relu(_value)


  func add_incoming_link(link: Link):
    incoming_links.append(link)


  func add_outgoing_link(link: Link):
    outgoing_links.append(link)



class Link:
  var id: int
  var source_node: NNNode
  var target_node: NNNode
  var weight: float


  func _init(_id, _source_node: NNNode, _target_node: NNNode, _weight):
    if _id < 0:
      id = Main.generate_UID()
    else:
      id = _id
    source_node = _source_node
    target_node = _target_node
    weight = _weight
    
    source_node.add_outgoing_link(self)
    target_node.add_incoming_link(self)


  func get_value():
    return source_node.get_value() * weight

