Chapter 5:  Runtime Control
===========================
	
Runtime Control provides an API by which various principals (e.g.,
users, operators) can make changes to a running system, primarily by
specifying new values for one or more runtime parameters.

Using Aether’s 5G connectivity service as an example, suppose an
enterprise user (or an enterprise admin, on that user's behalf) wants
to change the *QoS-Profile* for their mobile device from *Standard* to
*High-Priority*, or imagine a privileged operator wants to add a new
*Mission-Critical* option to the existing set of supported
*QoS-Profiles*. Without worrying about the exact syntax of the API
call(s) for these operations, the Runtime Control subsystem needs to

1. Authenticate the principal wanting to perform the operation.
   
2. Determine if that user has sufficient privilege to carry out the
   operation.
   
3. Push the new parameter setting(s) to one or more backend components.

4. Record the specified parameter setting(s), so the new value(s)
   persist.
   
In this example, *QoS-Profile* is an abstract object being operated
upon, and while this object must be understood by Runtime Control,
making changes to this object might involve invoking low-level control
operations on multiple subsystems, such as the SD-RAN (which is
responsible for QoS in the RAN), the SD-Fabric (which is responsible
for QoS through the switching fabric), SD-Core UP (which is
responsible for QoS in the mobile core user plane), and SD-Core CP
(which is responsible for QoS in the mobile core control plane).

In short, Runtime Control defines an abstraction layer on top of a
collection of backend components, effectively turning them into
externally visible (and controllable) cloud services. Sometimes a
single backend component implements the entirety of a service, in
which case Runtime Control may add little more than a Triple-A
layer. But for a cloud constructed from a collection of disaggregated
components, Runtime Control is where we define an API that logically
integrates those components into a unified and coherent set of
abstract services. It is also an opportunity to “raise the level of
abstraction” for the underlying subsystems.

5.1 Design Overview
-------------------

At a high level, the purpose of Runtime Control is to offer an API
that various stakeholders can use to configure and control cloud
services. In doing so, Runtime Control must:

* Support new end-to-end abstractions that may cross multiple backend
  subsystems.
  
* Associate control and configuration state with those abstractions.
  
* Support *versioning* of this configuration state, so changes can be
  rolled back as necessary, and an audit history may be retrieved of
  previous configurations.
  
* Adopt best practices of *performance*, *high availability*,
  *reliability*, and *security* in how this abstraction layer is
  implemented.
  
* Support *Role-Based Access Controls (RBAC)*, so that different
  principals have different visibility into and control over the
  underlying abstract objects.
  
* Be extensible, and so able to incorporate new services and new
  abstractions for existing services over time.
  
Central to this role is the requirement that Runtime Control be able
to represent a set of abstract objects, which is to say, it implements
a *data model*.  While there are several viable options for the
specification language used to represent the data model, for Runtime
Control we use YANG. This is for three reasons. First, YANG is a rich
language for data modeling, with support for strong validation of the
data stored in the models and the ability to define relations between
objects. Second, it is agnostic as to how the data is stored (i.e.,
not directly tied to SQL/RDBMS or NoSQL paradigms), giving us a
generous set of engineering options. Finally, YANG is widely used for
this purpose, meaning there is a robust collection of YANG-based tools
that we can build upon.

.. sidebar:: Web Frameworks

	*Talk about Frameworks like Django and Ruby on Rails and the
	role they play in SaaS. Call out declarative vs imparative
	design principle.*

	
With this background, :numref:`Figure %s <fig-roc>` shows the internal
structure of Runtime Control for Aether, which has **onos-config**\—a
microservice used in ONOS to maintain a set of YANG models for
configuring network devices—at its core. In Aether, onos-config is
re-purposed to use YANG models to control and configure cloud
services.\ [#]_ onos-config, in turn, uses Atomix (a Key/Value-Store
microservice), to make configuration state persistent. Because
onos-config was originally designed to manage configuration state for
devices, it uses gNMI as its southbound interface to communicate
configuration changes to devices (or in our case, software
services). An Adaptor has to be written for any service/device that
does not support gNMI natively. These adaptors are shown as part of
Runtime Control in :numref:`Figure %s <fig-roc>`, but it is equally
correct to view each adaptor as part of the backend component,
responsible for making that component management-ready. Finally,
Runtime Control includes a Workflow Engine that is responsible for
executing multi-step operations on the data model. This happens, for
example, when a change to one model triggers some action on another
model. Each of these components are described in more detail in the
next section.

.. [#] Because ONOS is part of the SD-Fabric and SD-RAN, which are
       responsible for configuring a set of devices, multiple
       onos-config microservices run within a single Aether
       cluster. Here, we focus on its role in managing services. It's
       a general (reusable) tool.
       
.. _fig-roc:
.. figure:: figures/Slide15.png
   :width: 500px
   :align: center

   Internal structure of Runtime Control, and its relationship to
   backend subsystems (below) and user portals/apps (above).

The Runtime Control API is auto-generated from the YANG-based data
model, and as shown in :numref:`Figure %s <fig-roc>`, supports two
portals and a set of closed-loop control applications. There is also a
CLI (not shown). This API provides a single point-of-entry for **all**
control information that can be read or written in Aether, and as a
consequence, Runtime Control also mediates access to the other
subsystems of the Control and Management Platform (not just the
subsystems shown in :numref:`Figure %s <fig-roc>`). This situation is
illustrated in :numref:`Figure %s <fig-roc2>`, where the key takeaway
is that (1) we want RBAC and auditing for all operations; (2) we want
a single source of authoritative configuration state; and (3) we want
to grant limited (fine-grained) access to management functions to
arbitrary principals rather than assume that only privileged operators
ever touch, say, some aspect of deployment. (We’ll see an example of
the latter in Section 5.3.)

Of course, the private APIs of the underlying subsystems still exist,
and operators can directly use them. This can be especially useful
when diagnosing problems. But for the three reasons given above, there
is a strong argument in favor of mediating all control activity using
the Runtime Control API. This is related to the “What About GitOps?”
question raised at the end of Chapter 4. Now that we have the option
of Runtime Control maintaining authoritative configuration and control
state for the system in its K/V store, how do we “share ownership” of
configuration state with the repositories that implement Lifecycle
Management?

One option is to decide on a case-by-case basis: Runtime Control
maintains authoritative state for some parameters and the code repos
maintain authoritative state for other parameters. We just need to be
clear about which is which, so each backend component knows which
“configuration path” it needs to be responsive to. Then, for any
repo-maintained state for which we want Runtime Control to mediate
access (e.g., to provide fine-grain access for a more expansive set of
principals), we need to be careful about the consequences of any
backdoor (direct) changes to that repo-maintained state, for example,
by storing only a cached copy of that state in Runtime Control’s
K/V-store (as an optimization).

.. _fig-roc2:
.. figure:: figures/Slide16.png
   :width: 500px
   :align: center

   Runtime Control also mediates access to the other Management
   Services.

One final aspect of :numref:`Figure %s <fig-roc2>` worth noting is
that, while Runtime Control mediates all control-related activity, it
is not in the “data path” for the subsystems it controls. This means,
for example, that monitoring data returned by the Monitoring & Logging
subsystem does not pass through Runtime Control; it is delivered
directly to dashboards and applications running on top of AMP. Runtime
Control is only involved in authorizing access to such data. It is
also the case that Runtime Control and the Monitoring subsystem have
their own, independent data stores: it is the Atomix K/V-Store for
Runtime Control and a Time-Series DB for Monitoring (as discussed in
more detail in Chapter 6).

5.2 Implementation Details
--------------------------

This section describes each of the components in Runtime Control,
focusing on the role each plays in cloud management.

Models & State
~~~~~~~~~~~~~~

Onos-config is the core of the Runtime Control. Its job is to store
and version configuration data. Configuration is pushed to onos-config
through its northbound gNMI interface, stored in an persistent
Key/Value-store, and pushed to backend subsystems using a southbound
gNMI interface.

A collection of YANG-based models define the schema for this
configuration state. These models are loaded into onos-config, and
collectively define the data model for all the configuration and
control state that Runtime Control is responsible for. As an example,
the data model (schema) for Aether is sketched in Section 5.3, but
another example would be the set of OpenConfig models used to manage
network devices.

There are three details of note:

* **Persistent Store:** Atomix is the cloud native K/V-store used to
  persist data in onos-config. Atomix supports a distributed map
  abstraction, which implements the Raft consensus algorithm to
  achieve fault-tolerance and scalable performance. Onos-config writes
  data to and reads data from Atomix using a simple GET/PUT interface
  common to NoSQL databases.
  
* **Loading Models:** A Kubernetes Operator (not shown in the figure),
  is responsible for configuring the models within onos-config. Models
  to load into onos-config are specified by a Helm chart. The operator
  compiles them on demand and incorporates them into onos-config. This
  eliminates dynamic load compatibility issues that are a problem when
  models and onos-config are built separately.
  
* **Migration:** All the models loaded into onos-config are versioned,
  and the process of updating those models triggers the migration of
  persistent state from one version of the data model to another. The
  migration mechanism supports simultaneous operation of multiple
  versions.
  
Control API
~~~~~~~~~~~

A Control API provides an *interface wrapper* that sits between
onos-config and higher-layer portals and applications. Northbound, it
offers a RESTful API. Southbound, it speaks gNMI to onos-config. It is
entirely possible to auto-generate the REST API from the set of models
loaded into onos-config, although one is also free to augment this set
with additional “hand-crafted” calls for the sake of convenience
(although typically this will mean the API is no longer RESTful).

The Control API layer serves multiple purposes:

* Unlike gNMI (which supports only **GET** and **SET** operations), a
  RESTful API (which supports **GET**, **PUT**, **POST**, **PATCH**,
  and **DELETE** operations)  is expected for GUI development.
  
* The API layer is an opportunity to implement early parameter
  validation and security checks. This makes it possible to catch
  errors closer to the user, and generate more meaningful error
  messages than is possible with gNMI.
  
* The API layer is an opportunity to implement semantic translation,
  adding methods that go beyond the auto-generated calls.
  
Identity Management
~~~~~~~~~~~~~~~~~~~

Runtime Control leverages an external identity database (i.e. LDAP
server) to store user data such as account names and passwords for
users who are able to log in. This LDAP server also has the capability
to associate users with groups. For example, adding administrators to
AetherAdmin would be a way to grant those people administrative
privileges within the ROC.

An external authentication service (DEX) is used to authenticate the
user, handling the mechanics of accepting the password, validating it,
and securely returning the group the user belongs to. The group
identifier is then used to grant access to resources within Runtime
Control.

The implementation of Runtime Control for Aether currently has its own
homegrown RBAC models, but an effort is underway to replace this with
Open Policy Framework (OPF).

Adapters
~~~~~~~~

Not every service or subsystem beneath Runtime Control supports gNMI,
and in the case where it is not supported, an adapter is written to
translate between gNMI and the service’s native API. In Aether, for
example, a gNMI :math:`\rightarrow` REST adapter translates between
the Runtime Control’s southbound gNMI calls and the SD-Core
subsystem’s RESTful northbound interface. The adapter is not
necessarily just a syntactic translator, but may also include its own
semantic layer. This supports a logical decoupling of the models
stored in onos-config and the interface used by the southbound
device/service, allowing the southbound device/service and Runtime
Control to evolve independently. It also allows for southbound
devices/services to be replaced without affecting the northbound
interface.

Workflow Engine
~~~~~~~~~~~~~~~

The workflow engine, to the left of the onos-config in :numref:`Figure
%s <fig-roc>`, is where multi-step workflows are implemented. For
example, defining a new Slice or associating subscribers with an
existing slice is a multi-step process, using several models and
impacting multiple backend subsystems. In our experience, there may
even be complex state machines that implement those steps.

There are well-known open source workflow engines (e.g., Airflow), but
our experience is that they do not match up with the types of
workflows typical of systems like Aether. As a consequence, the
current implementation is ad hoc, with imperative code watching a
target set of models and taking appropriate action whenever they
change. Defining a more rigorous approach to workflows is a subject of
ongoing development.

Secure Communication
~~~~~~~~~~~~~~~~~~~~

gNMI naturally lends itself to mutual TLS for authentication, and that
is the recommended way to secure communications between components
that speak gNMI. For example, communication between onos-config and
its adapters uses gNMI, and therefore, uses mutual TLS. Distributing
certificates between components is a problem outside the scope of
Runtime Control. It is assumed that another tool will be responsible
for distribution, renewing certificates before they expire,
etc.

For components that speak REST, HTTPS is used to secure the
connection, and authentication can take place using mechanisms within
the HTTPS protocol (basic auth, tokens, etc). Oath2 and OpenID Connect
are leveraged as an authorization provider when using these REST APIs.

5.3 Modeling Connectivity
----------------------------------------

Sketch the data model for Aether's connectivity service as a way of
illustrating the role Runtime Control plays.
