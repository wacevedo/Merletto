// Constrained Delaunay Triangulation code in JavaScript
// Copyright 2018 Savithru Jayasinghe
// Licensed under the MIT License (LICENSE.txt)

'use strict';

function emptyDict(d) {
	// https://www.destroyallsoftware.com/talks/wat
	for (let k in d) { return false; }
	return true;
}

function anyKey(d) {
	for (let k in d) { return k; }
	return null;
}

function isDelaunay2(v_tri, p) {
	const vecp0 = v_tri[0].sub(p);
	const vecp1 = v_tri[1].sub(p);
	const vecp2 = v_tri[2].sub(p);

	const p0_sq = vecp0.x * vecp0.x + vecp0.y * vecp0.y;
	const p1_sq = vecp1.x * vecp1.x + vecp1.y * vecp1.y;
	const p2_sq = vecp2.x * vecp2.x + vecp2.y * vecp2.y;

	const det = vecp0.x * (vecp1.y * p2_sq - p1_sq * vecp2.y)
		- vecp0.y * (vecp1.x * p2_sq - p1_sq * vecp2.x)
		+ p0_sq * (vecp1.x * vecp2.y - vecp1.y * vecp2.x);

	if (det > 0) //p is inside circumcircle of v_tri
		return false;
	else
		return true;
}

class Mesh {
	constructor() {
		this.reset();
	}

	reset() {
		this.vert = [];
		this.tri = [];
		this.adj = [];
		this.con_edge = [];
		this.vert_to_tri = [];

		this.vert_props = [];
	}

	numPoints() {
		return this.vert.length;
	}

	addPoint(p) {
		this.vert.push(p);
	}

	getPoint(i) {
		return this.vert[i];
	}

	setPoint(i, p) {
		this.vert[i] = p;
		this.recompute();
	}

	removePoint(i) {
		this.vert.splice(i, 1);

		// Adjust indices of all constraint edges.
		let ncon = [];
		for (let e of this.con_edge) {
			let a = e[0];
			let b = e[1];

			if ((a == i) || (b == i)) {
				continue;
			}

			if (a > i) {
				--a;
			}
			if (b > i) {
				--b;
			}

			ncon.push([a, b])
		}
		this.con_edges = ncon;

		this.recompute();
	}

	// Consumes two vertex indices
	addConstraint(i, j) {
		this.con_edge.push([i, j]);
		this.recompute();
	}

	// Consumes two vertex indices
	removeConstraint(i, j) {
		for (let idx = 0; idx < this.con_edge.length; ++idx) {
			const e = this.con_edge[idx];
			const a = e[0];
			const b = e[1];
			if (((i == a) && (j == b)) || ((i == b) && (j == a))) {
				removeConstraintAt(idx);
				return;
			}
		}
	}

	// Consumes an index into the array of edge constraints
	removeConstraintAt(i) {
		this.con_edges.splice(i, 1);
		this.recompute();
	}

	recompute() {
		// Reset the array of vertex properties.
		this.vert_props = [];
		for (let idx = 0; idx < this.vert.length; ++idx) {
			this.vert_props.push(
				{
					boundary: false
				});
		}

		if (this.vert.length >= 3) {
			this.delaunay()

			if (this.con_edge.length > 0) {
				this.constrainEdges();
			}

			this.calcGraphStructure();

			if (this.vert.length >= 3) {
				this.calcCirclePacking();
			}
		}
	}

	setupDelaunay() {
		let xmin = this.vert[0].x;
		let ymin = this.vert[0].y;
		let xmax = this.vert[0].x;
		let ymax = this.vert[0].y;

		for (let p of this.vert) {
			xmin = min(xmin, p.x);
			xmax = max(xmax, p.x);
			ymin = min(ymin, p.y);
			ymax = max(ymax, p.y);
		}

		const nVertex = this.vert.length;

		const di = 1000.0 * max(xmax - xmin, ymax - ymin);

		this.vert.push(new Point(-di + 0.5, -di / Math.sqrt(3) + 0.5));
		this.vert.push(new Point(di + 0.5, -di / Math.sqrt(3) + 0.5));
		this.vert.push(new Point(0.5, 2 * di / Math.sqrt(3) + 0.5));

		this.tri = [[nVertex, (nVertex + 1), (nVertex + 2)]];
		this.adj = [[-1, -1, -1]];
		this.vert_to_tri = [];
	}

	delaunay() {
		//Sort input vertices and setup super-triangle
		this.setupDelaunay();

		var verts = this.vert;
		var triangles = this.tri;
		var adjacency = this.adj;

		const N = verts.length - 3; //vertices includes super-triangle nodes

		var ind_tri = 0; //points to the super-triangle
		var nhops_total = 0;

		for (let new_i = 0; new_i < N; ++new_i) {
			const res = this.findEnclosingTriangle(verts[new_i], ind_tri);
			ind_tri = res[0];
			nhops_total += res[1];

			if (ind_tri === -1)
				throw "Could not find a triangle containing the new vertex!";

			let cur_tri = triangles[ind_tri]; //vertex indices of triangle containing new point
			let new_tri0 = [cur_tri[0], cur_tri[1], new_i];
			let new_tri1 = [new_i, cur_tri[1], cur_tri[2]];
			let new_tri2 = [cur_tri[0], new_i, cur_tri[2]];

			//Replace the triangle containing the point with new_tri0, and
			//fix its adjacency
			triangles[ind_tri] = new_tri0;

			const N_tri = triangles.length;
			const cur_tri_adj = adjacency[ind_tri]; //neighbors of cur_tri
			adjacency[ind_tri] = [N_tri, N_tri + 1, cur_tri_adj[2]];

			//Add the other two new triangles to the list
			triangles.push(new_tri1); //triangle index N_tri
			triangles.push(new_tri2); //triangle index (N_tri+1)

			adjacency.push([cur_tri_adj[0], N_tri + 1, ind_tri]); //adj for triangle N_tri
			adjacency.push([N_tri, cur_tri_adj[1], ind_tri]); //adj for triangle (N_tri+1)

			//stack of triangles which need to be checked for Delaunay condition
			//each element contains: [index of tri to check, adjncy index to goto triangle that contains new point]
			let stack = [];

			if (cur_tri_adj[2] >= 0) //if triangle cur_tri's neighbor exists
			{
				//Find the index for cur_tri in the adjacency of the neighbor
				const neigh_adj_ind = adjacency[cur_tri_adj[2]].indexOf(ind_tri);

				//No need to update adjacency, but push the neighbor on to the stack
				stack.push([cur_tri_adj[2], neigh_adj_ind]);
			}
			if (cur_tri_adj[0] >= 0) //if triangle N_tri's neighbor exists
			{
				//Find the index for cur_tri in the adjacency of the neighbor
				const neigh_adj_ind = adjacency[cur_tri_adj[0]].indexOf(ind_tri);
				adjacency[cur_tri_adj[0]][neigh_adj_ind] = N_tri;
				stack.push([cur_tri_adj[0], neigh_adj_ind]);
			}

			if (cur_tri_adj[1] >= 0) //if triangle (N_tri+1)'s neighbor exists
			{
				//Find the index for cur_tri in the adjacency of the neighbor
				const neigh_adj_ind = adjacency[cur_tri_adj[1]].indexOf(ind_tri);
				adjacency[cur_tri_adj[1]][neigh_adj_ind] = N_tri + 1;
				stack.push([cur_tri_adj[1], neigh_adj_ind]);
			}

			this.restoreDelaunay(new_i, stack);
		} //loop over vertices

		this.removeBoundaryTriangles();
	}

	//Uses edge orientations - based on Peter Brown's Technical Report 1997
	findEnclosingTriangle(target_vertex, ind_tri_cur) {
		var vertices = this.vert;
		var triangles = this.tri;
		var adjacency = this.adj;
		const max_hops = Math.max(10, adjacency.length);

		var nhops = 0;
		var found_tri = false;
		var path = [];

		while (!found_tri && nhops < max_hops) {
			if (ind_tri_cur === -1) //target is outside triangulation
				return [ind_tri_cur, nhops];

			var tri_cur = triangles[ind_tri_cur];

			//Orientation of target wrt each edge of triangle (positive if on left of edge)
			const orients = [getPointOrientation([vertices[tri_cur[1]], vertices[tri_cur[2]]], target_vertex),
			getPointOrientation([vertices[tri_cur[2]], vertices[tri_cur[0]]], target_vertex),
			getPointOrientation([vertices[tri_cur[0]], vertices[tri_cur[1]]], target_vertex)];

			if (orients[0] >= 0 && orients[1] >= 0 && orients[2] >= 0) //target is to left of all edges, so inside tri
				return [ind_tri_cur, nhops];

			var base_ind = -1;
			for (let iedge = 0; iedge < 3; iedge++) {
				if (orients[iedge] >= 0) {
					base_ind = iedge;
					break;
				}
			}
			const base_p1_ind = (base_ind + 1) % 3;
			const base_p2_ind = (base_ind + 2) % 3;

			if (orients[base_p1_ind] >= 0 && orients[base_p2_ind] < 0) {
				ind_tri_cur = adjacency[ind_tri_cur][base_p2_ind]; //should move to the triangle opposite base_p2_ind
				path[nhops] = vertices[tri_cur[base_ind]].add(vertices[tri_cur[base_p1_ind]]).scale(0.5);
			}
			else if (orients[base_p1_ind] < 0 && orients[base_p2_ind] >= 0) {
				ind_tri_cur = adjacency[ind_tri_cur][base_p1_ind]; //should move to the triangle opposite base_p1_ind
				path[nhops] = vertices[tri_cur[base_p2_ind]].add(vertices[tri_cur[base_ind]]).scale(0.5);
			}
			else {
				const vec0 = vertices[tri_cur[base_p1_ind]].sub(vertices[tri_cur[base_ind]]); //vector from base_ind to base_p1_ind
				const vec1 = target_vertex.sub(vertices[tri_cur[base_ind]]); //vector from base_ind to target_vertex
				if (vec0.dot(vec1) > 0) {
					ind_tri_cur = adjacency[ind_tri_cur][base_p2_ind]; //should move to the triangle opposite base_p2_ind
					path[nhops] = vertices[tri_cur[base_ind]].add(vertices[tri_cur[base_p1_ind]]).scale(0.5);
				}
				else {
					ind_tri_cur = adjacency[ind_tri_cur][base_p1_ind]; //should move to the triangle opposite base_p1_ind
					path[nhops] = vertices[tri_cur[base_p2_ind]].add(vertices[tri_cur[base_ind]]).scale(0.5);
				}
			}

			nhops++;
		}

		return [ind_tri_cur, (nhops - 1)];
	}

	restoreDelaunay(ind_vert, stack) {
		var vertices = this.vert;
		var triangles = this.tri;
		var adjacency = this.adj;
		var v_new = vertices[ind_vert];

		while (stack.length > 0) {
			const ind_tri_pair = stack.pop(); //[index of tri to check, adjncy index to goto triangle that contains new point]
			const ind_tri = ind_tri_pair[0];

			const ind_tri_vert = triangles[ind_tri]; //vertex indices of the triangle
			let v_tri = [];
			for (let i = 0; i < 3; i++)
				v_tri[i] = vertices[ind_tri_vert[i]];

			if (!isDelaunay2(v_tri, v_new)) {
				//v_new lies inside the circumcircle of the triangle, so need to swap diagonals

				const outernode_tri = ind_tri_pair[1]; // [0,1,2] node-index of vertex that's not part of the common edge
				const ind_tri_neigh = adjacency[ind_tri][outernode_tri];

				if (ind_tri_neigh < 0)
					throw "negative index";

				//Swap the diagonal between the adjacent triangles
				this.swapDiagonal(ind_tri, ind_tri_neigh);

				//Add the triangles opposite the new vertex to the stack
				const new_node_ind_tri = triangles[ind_tri].indexOf(ind_vert);
				const ind_tri_outerp2 = adjacency[ind_tri][new_node_ind_tri];
				if (ind_tri_outerp2 >= 0) {
					const neigh_node = adjacency[ind_tri_outerp2].indexOf(ind_tri);
					stack.push([ind_tri_outerp2, neigh_node]);
				}

				const new_node_ind_tri_neigh = triangles[ind_tri_neigh].indexOf(ind_vert);
				const ind_tri_neigh_outer = adjacency[ind_tri_neigh][new_node_ind_tri_neigh];
				if (ind_tri_neigh_outer >= 0) {
					const neigh_node = adjacency[ind_tri_neigh_outer].indexOf(ind_tri_neigh);
					stack.push([ind_tri_neigh_outer, neigh_node]);
				}

			} //is not Delaunay
		}
	}

	//Swaps the diagonal of adjacent triangles A and B
	swapDiagonal(ind_triA, ind_triB) {
		var triangles = this.tri;
		var adjacency = this.adj;
		var vert2tri = this.vert_to_tri;

		//Find the node index of the outer vertex in each triangle
		const outernode_triA = adjacency[ind_triA].indexOf(ind_triB);
		const outernode_triB = adjacency[ind_triB].indexOf(ind_triA);

		//Indices of nodes after the outernode (i.e. nodes of the common edge)
		const outernode_triA_p1 = (outernode_triA + 1) % 3;
		const outernode_triA_p2 = (outernode_triA + 2) % 3;

		const outernode_triB_p1 = (outernode_triB + 1) % 3;
		const outernode_triB_p2 = (outernode_triB + 2) % 3;

		//Update triangle nodes
		triangles[ind_triA][outernode_triA_p2] = triangles[ind_triB][outernode_triB];
		triangles[ind_triB][outernode_triB_p2] = triangles[ind_triA][outernode_triA];

		//Update adjacencies for triangle opposite outernode
		adjacency[ind_triA][outernode_triA] = adjacency[ind_triB][outernode_triB_p1];
		adjacency[ind_triB][outernode_triB] = adjacency[ind_triA][outernode_triA_p1];

		//Update adjacency of neighbor opposite triangle A's (outernode+1) node
		const ind_triA_neigh_outerp1 = adjacency[ind_triA][outernode_triA_p1];
		if (ind_triA_neigh_outerp1 >= 0) {
			const neigh_node = adjacency[ind_triA_neigh_outerp1].indexOf(ind_triA);
			adjacency[ind_triA_neigh_outerp1][neigh_node] = ind_triB;
		}

		//Update adjacency of neighbor opposite triangle B's (outernode+1) node
		const ind_triB_neigh_outerp1 = adjacency[ind_triB][outernode_triB_p1];
		if (ind_triB_neigh_outerp1 >= 0) {
			const neigh_node = adjacency[ind_triB_neigh_outerp1].indexOf(ind_triB);
			adjacency[ind_triB_neigh_outerp1][neigh_node] = ind_triA;
		}

		//Update adjacencies for triangles opposite the (outernode+1) node
		adjacency[ind_triA][outernode_triA_p1] = ind_triB;
		adjacency[ind_triB][outernode_triB_p1] = ind_triA;

		//Update vertex to triangle connectivity, if data structure exists
		if (vert2tri.length > 0) {
			//The original outernodes will now be part of both triangles
			vert2tri[triangles[ind_triA][outernode_triA]].push(ind_triB);
			vert2tri[triangles[ind_triB][outernode_triB]].push(ind_triA);

			//Remove triangle B from the triangle set of outernode_triA_p1
			let local_ind = vert2tri[triangles[ind_triA][outernode_triA_p1]].indexOf(ind_triB);
			vert2tri[triangles[ind_triA][outernode_triA_p1]].splice(local_ind, 1);

			//Remove triangle A from the triangle set of outernode_triB_p1
			local_ind = vert2tri[triangles[ind_triB][outernode_triB_p1]].indexOf(ind_triA);
			vert2tri[triangles[ind_triB][outernode_triB_p1]].splice(local_ind, 1);
		}
	}

	removeBoundaryTriangles() {
		var verts = this.vert;
		var triangles = this.tri;
		var adjacency = this.adj;
		const N = verts.length - 3;

		var del_count = 0;
		var indmap = [];
		for (let i = 0; i < triangles.length; i++) {
			let prev_del_count = del_count;
			for (let j = i; j < triangles.length; j++) {
				if (triangles[j][0] < N && triangles[j][1] < N && triangles[j][2] < N) {
					indmap[i + del_count] = i;
					break;
				} else {
					// The non-extra vertices in this triangle are boundary vertices.
					for (let v = 0; v < 3; ++v) {
						const vidx = triangles[j][v];
						if (vidx < N) {
							this.vert_props[vidx].boundary = true;
						}
					}
					indmap[i + del_count] = -1;
					del_count++;
				}
			}

			let del_length = del_count - prev_del_count;
			if (del_length > 0) {
				triangles.splice(i, del_length);
				adjacency.splice(i, del_length);
			}
		}

		//Update adjacencies
		for (let i = 0; i < adjacency.length; i++)
			for (let j = 0; j < 3; j++)
				adjacency[i][j] = indmap[adjacency[i][j]];

		//Delete super-triangle nodes
		this.vert.splice(-3, 3);
	}

	constrainEdges() {
		if (this.con_edge.length == 0)
			return;

		this.buildVertexConnectivity();

		var con_edges = this.con_edge;
		var triangles = this.tri;
		var verts = this.vert;
		var adjacency = this.adj;
		var vert2tri = this.vert_to_tri;

		var newEdgeList = [];

		for (let iedge = 0; iedge < con_edges.length; iedge++) {
			let intersections = this.getEdgeIntersections(iedge);

			let iter = 0;
			const maxIter = Math.max(intersections.length, 1);
			while (intersections.length > 0 && iter < maxIter) {
				this.fixEdgeIntersections(intersections, iedge, newEdgeList);
				intersections = this.getEdgeIntersections(iedge);
				iter++;
			}

			if (intersections.length > 0)
				throw "Could not add edge " + iedge + " to triangulation after " + maxIter + " iterations!";

		} //loop over constrained edges

		//Restore Delaunay
		while (true) {
			let num_diagonal_swaps = 0;
			for (let iedge = 0; iedge < newEdgeList.length; iedge++) {
				const new_edge_nodes = newEdgeList[iedge];

				//Check if the new edge is a constrained edge
				let is_con_edge = false
				for (let jedge = 0; jedge < con_edges.length; jedge++) {
					if (isSameEdge(new_edge_nodes, con_edges[jedge])) {
						is_con_edge = true;
						break;
					};
				}

				if (is_con_edge)
					continue; //cannot change this edge if it's constrained

				const tri_around_v0 = vert2tri[new_edge_nodes[0]];
				let tri_count = 0;
				let tri_ind_pair = [-1, -1]; //indices of the triangles on either side of this edge
				for (let itri = 0; itri < tri_around_v0.length; itri++) {
					const cur_tri = triangles[tri_around_v0[itri]];
					if (cur_tri[0] == new_edge_nodes[1] || cur_tri[1] == new_edge_nodes[1] || cur_tri[2] == new_edge_nodes[1]) {
						tri_ind_pair[tri_count] = tri_around_v0[itri];
						tri_count++;

						if (tri_count == 2)
							break; //found both neighboring triangles
					}
				}

				if (tri_ind_pair[0] == -1)
					continue; //this edge no longer exists, so nothing to do.

				const triA_verts = [verts[triangles[tri_ind_pair[0]][0]],
				verts[triangles[tri_ind_pair[0]][1]],
				verts[triangles[tri_ind_pair[0]][2]]];

				const outer_nodeB_ind = adjacency[tri_ind_pair[1]].indexOf(tri_ind_pair[0]);
				const triB_vert = verts[triangles[tri_ind_pair[1]][outer_nodeB_ind]];

				if (!isDelaunay2(triA_verts, triB_vert)) {
					const outer_nodeA_ind = adjacency[tri_ind_pair[0]].indexOf(tri_ind_pair[1]);

					//Swap the diagonal between the pair of triangles
					this.swapDiagonal(tri_ind_pair[0], tri_ind_pair[1]);
					num_diagonal_swaps++;

					//Replace current new edge with the new diagonal
					newEdgeList[iedge] = [triangles[tri_ind_pair[0]][outer_nodeA_ind],
					triangles[tri_ind_pair[1]][outer_nodeB_ind]];
				}

			} //loop over new edges

			if (num_diagonal_swaps == 0)
				break; //no further swaps, we're done.
		}
	}

	buildVertexConnectivity() {
		var triangles = this.tri;
		this.vert_to_tri = [];
		var vConnectivity = this.vert_to_tri;

		for (let itri = 0; itri < triangles.length; itri++) {
			for (let node = 0; node < 3; node++) {
				if (vConnectivity[triangles[itri][node]] == undefined)
					vConnectivity[triangles[itri][node]] = [itri];
				else
					vConnectivity[triangles[itri][node]].push(itri);
			}
		}
	}

	getEdgeIntersections(iedge) {
		var triangles = this.tri;
		var verts = this.vert;
		var adjacency = this.adj;
		var con_edges = this.con_edge;
		var vert2tri = this.vert_to_tri;

		const edge_v0_ind = con_edges[iedge][0];
		const edge_v1_ind = con_edges[iedge][1];
		const edge_coords = [verts[edge_v0_ind], verts[edge_v1_ind]];

		const tri_around_v0 = vert2tri[edge_v0_ind];

		let edge_in_triangulation = false;

		//stores the index of tri that intersects current edge,
		//and the edge-index of intersecting edge in triangle
		let intersections = [];

		for (let itri = 0; itri < tri_around_v0.length; itri++) {
			const cur_tri = triangles[tri_around_v0[itri]];
			const v0_node = cur_tri.indexOf(edge_v0_ind);
			const v0p1_node = (v0_node + 1) % 3;
			const v0p2_node = (v0_node + 2) % 3;

			if (edge_v1_ind == cur_tri[v0p1_node]) {
				//constrained edge is an edge of the current tri (node v0_node to v0_node+1)
				edge_in_triangulation = true;
				break;
			}
			else if (edge_v1_ind == cur_tri[v0p2_node]) {
				//constrained edge is an edge of the current tri (node v0_node to v0_node+2)
				edge_in_triangulation = true;
				break;
			}

			const opposite_edge_coords = [verts[cur_tri[v0p1_node]], verts[cur_tri[v0p2_node]]];
			if (isEdgeIntersecting(edge_coords, opposite_edge_coords)) {
				intersections.push([tri_around_v0[itri], v0_node]);
				break;
			}
		}

		if (!edge_in_triangulation) {
			if (intersections.length == 0)
				throw "Cannot have no intersections!";

			while (true) {
				const prev_intersection = intersections[intersections.length - 1]; //[tri ind][node ind for edge]
				const tri_ind = adjacency[prev_intersection[0]][prev_intersection[1]];

				if (triangles[tri_ind][0] == edge_v1_ind ||
					triangles[tri_ind][1] == edge_v1_ind ||
					triangles[tri_ind][2] == edge_v1_ind) {
					break; //found the end node of the edge
				}

				//Find the index of the edge from which we came into this triangle
				let prev_edge_ind = adjacency[tri_ind].indexOf(prev_intersection[0]);
				if (prev_edge_ind == -1)
					throw "Could not find edge!";

				const cur_tri = triangles[tri_ind];

				//Loop over the other two edges in this triangle,
				//and check if they intersect the constrained edge
				for (let offset = 1; offset < 3; offset++) {
					const v0_node = (prev_edge_ind + offset + 1) % 3;
					const v1_node = (prev_edge_ind + offset + 2) % 3;
					const cur_edge_coords = [verts[cur_tri[v0_node]], verts[cur_tri[v1_node]]];

					if (isEdgeIntersecting(edge_coords, cur_edge_coords)) {
						intersections.push([tri_ind, (prev_edge_ind + offset) % 3]);
						break;
					}
				}

			} //while intersections not found
		} //if edge not in triangulation

		return intersections;
	}

	fixEdgeIntersections(intersectionList, con_edge_ind, newEdgeList) {
		var triangles = this.tri;
		var verts = this.vert;
		var adjacency = this.adj;
		var con_edges = this.con_edge;

		//Node indices and endpoint coords of current constrained edge
		var con_edge_nodes = con_edges[con_edge_ind];
		var cur_con_edge_coords = [verts[con_edge_nodes[0]], verts[con_edge_nodes[1]]];

		var nIntersections = intersectionList.length;
		for (let i = 0; i < nIntersections; i++) {
			//Looping in reverse order is important since then the
			//indices in intersectionList remain unaffected by any diagonal swaps
			const tri0_ind = intersectionList[nIntersections - 1 - i][0];
			const tri0_node = intersectionList[nIntersections - 1 - i][1];

			const tri1_ind = adjacency[tri0_ind][tri0_node];
			const tri1_node = adjacency[tri1_ind].indexOf(tri0_ind);

			const quad_v0 = verts[triangles[tri0_ind][tri0_node]];
			const quad_v1 = verts[triangles[tri0_ind][(tri0_node + 1) % 3]];
			const quad_v2 = verts[triangles[tri1_ind][tri1_node]];
			const quad_v3 = verts[triangles[tri0_ind][(tri0_node + 2) % 3]];

			const isConvex = isQuadConvex(quad_v0, quad_v1, quad_v2, quad_v3);

			if (isConvex) {
				this.swapDiagonal(tri0_ind, tri1_ind);

				const newDiagonal_nodes = [triangles[tri0_ind][tri0_node], triangles[tri1_ind][tri1_node]];

				const newDiagonal_coords = [quad_v0, quad_v2];
				const hasCommonNode = (newDiagonal_nodes[0] == con_edge_nodes[0] || newDiagonal_nodes[0] == con_edge_nodes[1] ||
					newDiagonal_nodes[1] == con_edge_nodes[0] || newDiagonal_nodes[1] == con_edge_nodes[1]);
				if (hasCommonNode || !isEdgeIntersecting(cur_con_edge_coords, newDiagonal_coords)) {
					newEdgeList.push([newDiagonal_nodes[0], newDiagonal_nodes[1]]);
				}

			} //is convex

		} //loop over intersections
	}

	insertAdjUnique(a, b) {
		let arr = this.vert_props[a].adj;
		for (let v of arr) {
			if (v == b) {
				return;
			}
		}

		arr.push(b);
	}

	calcGraphStructure() {
		// Calculate the CCW ring of adjacent vertices around each vertex.
		for (let idx = 0; idx < this.vert.length; ++idx) {
			this.vert_props[idx].adj = {};
		}

		// Prime dictionaries with adjacencies
		for (let T of this.tri) {
			this.vert_props[T[0]].adj[T[1]] = true;
			this.vert_props[T[1]].adj[T[0]] = true;
			this.vert_props[T[0]].adj[T[2]] = true;
			this.vert_props[T[2]].adj[T[0]] = true;
			this.vert_props[T[1]].adj[T[2]] = true;
			this.vert_props[T[2]].adj[T[1]] = true;
		}

		// Now turn each dictionary into a sorted circular list.
		for (let idx = 0; idx < this.vert.length; ++idx) {
			const cen = this.vert[idx];
			const a = Object.keys(this.vert_props[idx].adj);
			// Prevent ambiguous this reference
			let thingy = this;

			a.sort(function (v1, v2) {
				const p = thingy.vert[v1].sub(cen);
				const q = thingy.vert[v2].sub(cen);

				if (atan2(p.y, p.x) < atan2(q.y, q.x)) {
					return -1;
				} else {
					return 1;
				}
			});

			this.vert_props[idx].adj = a;
		}
	}

	calcCirclePacking() {
		const tolerance = 1.0 + 10e-12;

		let internal = {};
		let external = {};

		for (let idx = 0; idx < this.vert.length; ++idx) {
			if (this.vert_props[idx].boundary) {
				external[idx] = 1.0;
			} else {
				internal[idx] = this.vert_props[idx].adj;
			}
		}

		if (emptyDict(internal)) {
			return;
		}

		let radii = { ...external };

		for (let k in internal) {
			radii[k] = 1.0;
		}

		let lastChange = 2;
		while (lastChange > tolerance) {
			lastChange = 1;
			for (let k in internal) {
				const ring = internal[k]
				const rad = radii[k]

				let theta = this.flower(radii, k, ring);
				let hat = rad / (1.0 / sin(theta / (2 * ring.length)) - 1);
				let newrad = hat * (1.0 / (sin(PI / ring.length)) - 1);
				let kc = max(newrad / rad, rad / newrad);
				lastChange = max(lastChange, kc);
				radii[k] = newrad;
			}
		}

		let placements = {}
		let k1 = anyKey(internal);
		placements[k1] = new Point(0.0, 0.0);
		let k2 = this.vert_props[k1].adj[0];
		placements[k2] = new Point(radii[k1] + radii[k2], 0.0);
		this.place(placements, radii, internal, k1);
		this.place(placements, radii, internal, k2);

		for (let k in placements) {
			let vp = this.vert_props[k];
			vp.center = placements[k];
			vp.radius = radii[k];
		}
	}

	flower(radius, center, cycle) {
		let total = 0.0;
		const len = cycle.length;
		for (let i = 0; i < len; ++i) {
			total += this.acxyz(
				radius[center], radius[cycle[i]], radius[cycle[(i + 1) % len]]);
		}
		return total
	}

	acxyz(x, y, z) {
		let den = (2.0 * (x + y) * (x + z));
		let rat = (sq(x + y) + sq(x + z) - sq(y + z)) / den;
		return acos(rat);
	}

	place(placements, radii, internal, center) {
		if (!(center in internal)) {
			return;
		}
		let cycle = internal[center];
		const len = cycle.length;
		for (let i = -len; i < len - 1; ++i) {
			if ((cycle[(i + len) % len] in placements)
				&& !(cycle[(i + 1 + len) % len] in placements)) {
				let s = cycle[(i + len) % len];
				let t = cycle[(i + 1 + len) % len];
				let theta = this.acxyz(radii[center], radii[s], radii[t]);
				let offset = placements[s].sub(placements[center]).scale(
					1.0 / (radii[s] + radii[center]));
				let cang = cos(-theta);
				let sang = sin(-theta);
				offset = new Point(
					cang * offset.x - sang * offset.y,
					sang * offset.x + cang * offset.y);
				placements[t] = placements[center].add(
					offset.scale(radii[t] + radii[center]));
				this.place(placements, radii, internal, t);
			}
		}
	}
}
