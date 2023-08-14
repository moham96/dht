// ignore_for_file: constant_identifier_names

import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart' as bencoder;
import 'package:dtorrent_common/dtorrent_common.dart';

import '../kademlia/node.dart';

/// A KRPC message is a single dictionary with three keys common to every message
/// and additional keys depending on the type of message.
///
/// Every message has a key "t" with a string value representing a transaction ID.
/// This transaction ID is generated by the querying node and is echoed in the response,
/// so responses may be correlated with multiple queries to the same node.
/// The transaction ID should be encoded as a short string of binary numbers, typically
///  2 characters are enough as they cover 2^16 outstanding queries.
///
/// Every message also has a key "y" with a single character value describing the type
/// of message. The value of the "y" key is one of "q" for query, "r" for response,
/// or "e" for error.
///
/// A key "v" should be included in every message with a client version string.
/// The string should be a two character client identifier registered in
/// [BEP 20](http://www.bittorrent.org/beps/bep_0020.html)
/// followed by a two character version identifier.
///

const TRANSACTION_KEY = 't';
const METHOD_KEY = 'y';
const QUERY_KEY = 'q';
const RESPONSE_KEY = 'r';
const ERROR_KEY = 'e';
const ARGUMENTS_KEY = 'a';
const ID_KEY = 'id';
const TARGET_KEY = 'target';
const NODES_KEY = 'nodes';
const VALUES_KEY = 'values';
const INFO_HASH_KEY = 'info_hash';
const TOKEN_KEY = 'token';

const PING = 'ping';
const FIND_NODE = 'find_node';
const GET_PEERS = 'get_peers';
const ANNOUNCE_PEER = 'announce_peer';

const QUERY_KEYS = [PING, FIND_NODE, GET_PEERS, ANNOUNCE_PEER];

/// [transactionId] should be encoded as a short string of binary numbers, typically
///  2 characters are enough as they cover 2^16 outstanding queries.
Uint8List queryMessage(String transactionId, String method, Map arguments) {
  assert(transactionId.length == 2, 'Transaction ID length should be 2');
  var message = {
    TRANSACTION_KEY: transactionId,
    METHOD_KEY: QUERY_KEY,
    QUERY_KEY: method,
    ARGUMENTS_KEY: arguments
  };
  return bencoder.encode(message);
}

Uint8List responseMessage(String transactionId, Map response) {
  var message = {
    TRANSACTION_KEY: transactionId,
    METHOD_KEY: RESPONSE_KEY,
    RESPONSE_KEY: response
  };
  return bencoder.encode(message);
}

/// `error = {"t":"aa", "y":"e", "e":[201, "A Generic Error Ocurred"]}`
List<int> errorMessage(String transactionId, int code, String errorMsg) {
  var message = {
    TRANSACTION_KEY: transactionId,
    METHOD_KEY: ERROR_KEY,
    ERROR_KEY: [code, errorMsg]
  };
  return bencoder.encode(message);
}

/// `Ping` method query message.
///
///  arguments:  `{"id" : "<querying nodes id>"}`
///
/// [nodeId] is 20 length string,[transactionId] is 2 length string
Uint8List pingMessage(String transactionId, String nodeId) {
  return queryMessage(transactionId, PING, {ID_KEY: nodeId});
}

/// `response: {"id" : "<queried nodes id>"}`
Uint8List pongMessage(String transactionId, String nodeId) {
  return responseMessage(transactionId, {ID_KEY: nodeId});
}

/// `arguments:  {"id" : "<querying nodes id>", "target" : "<id of target node>"}`
Uint8List findNodeMessage(
    String transactionId, String nodeId, String targetId) {
  return queryMessage(
      transactionId, FIND_NODE, {ID_KEY: nodeId, TARGET_KEY: targetId});
}

/// `response: {"id" : "<queried nodes id>", "nodes" : "<compact node info>"}`
///
/// Contact information for nodes is encoded as a 26-byte string.
/// Also known as "Compact node info" the 20-byte Node ID in network byte order
/// has the compact IP-address/port info concatenated to the end.
Uint8List findNodeResponse(
    String transactionId, String nodeId, Iterable<Node> nodes) {
  var nodesStr = nodes.fold('', (previousValue, node) {
    return '$previousValue${node.toContactEncodingString()}';
  });
  return responseMessage(transactionId, {ID_KEY: nodeId, NODES_KEY: nodesStr});
}

/// `arguments:  {"id" : "<querying nodes id>", "info_hash" : "<20-byte infohash of target torrent>"}`
Uint8List getPeersMessage(
    String transactionId, String nodeId, String infoHash) {
  return queryMessage(
      transactionId, GET_PEERS, {ID_KEY: nodeId, INFO_HASH_KEY: infoHash});
}

/// response : `{"id" : "<queried nodes id>", "token" :"<opaque write token>", "values" : ["<peer 1 info string>", "<peer 2 info string>"],"nodes" : "<compact node info>"}`
Uint8List getPeersResponse(String transactionId, String nodeId, String token,
    {Iterable<Node>? nodes, Iterable<CompactAddress>? peers}) {
  String? nodesStr;
  if (nodes != null && nodes.isNotEmpty) {
    nodesStr = nodes.fold<String>('', (previousValue, node) {
      return '$previousValue${node.toContactEncodingString()}';
    });
  }
  List<String>? values;
  if (peers != null && peers.isNotEmpty) {
    values = [];
    for (var peer in peers) {
      values.add(peer.toContactEncodingString());
    }
  }
  var r = <String, dynamic>{ID_KEY: nodeId, 'token': token};
  if (nodesStr != null) {
    r[NODES_KEY] = nodesStr;
  }
  if (values != null) {
    r[VALUES_KEY] = values;
  }
  return responseMessage(transactionId, r);
}

/*
arguments:  {"id" : "<querying nodes id>",
  "implied_port": <0 or 1>,
  "info_hash" : "<20-byte infohash of target torrent>",
  "port" : <port number>,
  "token" : "<opaque token>"} 
*/
List<int> announcePeerMessage(String transactionId, String nodeId,
    String infoHash, int port, String token,
    [bool impliedPort = true]) {
  return queryMessage(transactionId, ANNOUNCE_PEER, {
    'implied_port': impliedPort ? 1 : 0,
    ID_KEY: nodeId,
    INFO_HASH_KEY: infoHash,
    'port': port,
    TOKEN_KEY: token
  });
}

/// `response: {"id" : "<queried nodes id>"}`
List<int> announcePeerResponse(String transactionId, String nodeId) {
  return responseMessage(transactionId, {ID_KEY: nodeId});
}
