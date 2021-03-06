/*
Copyright 2013-present Barefoot Networks, Inc. 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "includes/headers.p4"
#include "includes/parser.p4"
#define FIVE_TUPLE_OPERATION
//#define CHAINED_OPERATION

action _nop() {
}

action _drop() {
    drop();
}

action set_nhop(nhop_ipv4, port) {
    modify_field(routing_metadata.nhop_ipv4, nhop_ipv4);
    modify_field(standard_metadata.egress_spec, port);
    add_to_field(ipv4.ttl, -1);
}

action set_dmac(dmac) {
    modify_field(ethernet.dstAddr, dmac);
}

action rewrite_mac(smac) {
    modify_field(ethernet.srcAddr, smac);
}

/*
#ifdef L4_OPERATION
action set_egress_tcp_port() {
	modify_field(l3_metadata.egress_l4_sport, tcp.srcPort);
	modify_field(l3_metadata.egress_l4_dport, tcp.dstPort);
}

action set_egress_udp_port() {
	modify_field(l3_metadata.egress_l4_sport, udp.srcPort);
	modify_field(l3_metadata.egress_l4_dport, udp.dstPort);
}

table egress_l4_port_fields {
	reads {
		tcp : vaild;
		udp : vaild;
	}
	actions {
		nop;
		set_egress_tcp_port;
		set_egress_udp_port;
	}
	size: 256;
}

#endif
*/

table ipv4_lpm {
    reads {
        ipv4.dstAddr : lpm;
    }
    actions {
        set_nhop;
        _drop;
    }
    size: BASIC_ROUTING_TABLE_SIZE;
}

table forward {
    reads {
        routing_metadata.nhop_ipv4 : exact;
    }
    actions {
        set_dmac;
        _drop;
    }
    size: BASIC_ROUTING_TABLE_SIZE;
}

#ifdef FIVE_TUPLE_OPERATION

table ip_acl {
	reads {
		ipv4.srcAddr : ternary;
		ipv4.dstAddr : ternary;
		ipv4.protocol : ternary;
		l3_metadata.l4_sport : ternary;
		l3_metadata.l4_dport : ternary;
	}
	actions {
		_nop;
		_drop;
	}
	size: FIVE_TUPLE_ACL_TABLE_SIZE;
}
#endif

table send_frame {
    reads {
        standard_metadata.egress_port: exact;
    }
    actions {
        rewrite_mac;
        _drop;
    }
    size: EGRESS_TABLE_SIZE;
}

#ifdef CHAINED_OPERATION

table l3_acl {
	reads {
		ipv4.srcAddr : ternary;
		ipv4.dstAddr : ternary;
		ipv4.protocol : ternary;
	}
	actions {
		_nop;
		_drop;
	}
	size: L3_ACL_TABLE_SIZE;
}

table l4_port_acl {
	reads {
		l3_metadata.l4_sport : ternary;
		l3_metadata.l4_dport : ternary;
	}
	actions {
		_nop;
		_drop;
	}
	size: L4_ACL_TABLE_SIZE;
}


#endif

#ifndef CHAINED_OPERATION
control ingress {
    apply(ipv4_lpm);
    apply(forward);
    apply(ip_acl);
}
#endif

#ifdef CHAINED_OPERATION
control ingress {
	apply(ipv4_lpm){
		hit{
			apply(l3_acl){
				hit{
					apply(l4_port_acl);
				}
			}
		}
	}
	apply(forward);

	
}
#endif

control egress {
    apply(send_frame);
}
