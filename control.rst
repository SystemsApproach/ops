Chapter 5:  Runtime Control
===========================
	
Runtime Control provides an API by which various principals, such as
end-users, enterprise admins, and cloud operators, can make changes to
a running system, by specifying new values for one or more runtime
parameters.

Using Aether’s 5G connectivity service as an example, suppose an
enterprise admin wants to change the *QoS-Profile* setting for a group
of mobile devices. This might include modifying the *Uplink* or
*Downlink* bandwidth, or even selecting a different *Traffic
Class*. Similarly, imagine an operator wants to add a new
*Mission-Critical* option to the existing set of *Traffic Classes*
that *QoS-Profiles* can adopt. Without worrying about the exact syntax
of the API call(s) for these operations, the Runtime Control subsystem
needs to

1. Authenticate the principal wanting to perform the operation.
   
2. Determine if that principal has sufficient privilege to carry out the
   operation.
   
3. Push the new parameter setting(s) to one or more backend components.

4. Record the specified parameter setting(s), so the new value(s)
   persist.
   
In this example, *QoS-Profile* and *Traffic Class* are abstract
objects being operated upon, and while these objects must be
understood by Runtime Control, making changes to them might involve
invoking low-level control operations on multiple subsystems, such as
the SD-RAN (which is responsible for QoS in the RAN), the SD-Fabric
(which is responsible for QoS through the switching fabric), SD-Core
UP (which is responsible for QoS in the mobile core user plane), and
SD-Core CP (which is responsible for QoS in the mobile core control
plane).

In short, Runtime Control defines an abstraction layer on top of a
collection of backend components, effectively turning them into
externally visible (and controllable) cloud services. Sometimes a
single backend component implements the entirety of a service, in
which case Runtime Control may add little more than a Triple-A
layer. But for a cloud constructed from a collection of disaggregated
components, Runtime Control is where we define an API that logically
integrates those components into a unified and coherent set of
abstract services. It is also an opportunity to “raise the level of
abstraction” for the underlying subsystems and hiding implementation
details.

Defining a set of abstractions and the corresponding API is a
challenging job. Having the appropriate tools helps to focus on the
creative part of that task, but by no means eliminates it. The
challenge is partly a matter of judgment about what should be visible
to users and what should be a hidden implementation detail, and partly
about dealing with conflicting/conflated concepts and terminology.
We'll see a full example in Section 5.3, but to illustrate the
difficulty, consider how Aether refers to principals in its 5G
connectivity service. If we were to borrow terminology directly from
the Telcos, then we'd refer to someone that uses a mobile device as a
*subscriber*, implying an account and a collection of settings for the
service delivered to that device. And in fact, subscriber is a central
object within the SD-Core implementation.  But Aether is designed to
support enterprise deployments of 5G, and to that end, defines a
*user* to be a principal that accesses the API or GUI portal with some
prescribed level of privilege. There is not necessarily a one-to-one
relationship between users and Core-defined subscribers, and more
importantly, not all devices have subscribers, as would be the case
with IoT devices that are not typically associated with a particular
person.

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

.. _reading_yang:
.. admonition:: Further Reading

   `YANG - A Data Modeling Language for the Network Configuration Protocol
   <https://datatracker.ietf.org/doc/html/rfc6020>`__. RFC 6020. October 2010.

.. sidebar:: Web Frameworks

	*The role Runtime Control plays in operationalizing a cloud is
	similar to the role a Web Framework plays in operationalizing
	a web service. If you start with the assumption that certain
	classes of users will interact with your system (in our case,
	an edge cloud) via a GUI, then either you write that GUI in a
	language like PHP (as early web deverlopers did), our you take
	advantage of a framework like Django or Ruby on Rails. What
	such frameworks provide is a way to define a set of
	user-friendely abstractions (these are called Models), a means
	to visualize those abstractions in a GUI (these are called
	Views), and a means to affect change on collection of backend
	systems based on user input (these are called Controllers). It
	is not an accident that Model-View-Controller (MVP) is a
	well-understood design paradigm.*

	*The Runtime Control system described in this chapter adopts a
	similar approach, but instead of defining the models in Python
	(as with Django) or Ruby (as with Ruby on Rails), we define
	models using a declarative language—YANG—which is in turn used
	to generate a programmatic API. This API can then be invoked
	from (1) a GUI, which is itself typically built using another
	framework, such as AngularJS; (2) a CLI; or (3) a closed-loop
	control program. There are other differences—for example,
	Adaptors (a kind of Controller) use gNMI as a standard
	interface for controlling backend components, and persistent
	state is stored in a K/V Store instead of a SQL DB—but the
	biggest difference is the use of a declarative rather than an
	imparative language to define models.*

With this background, :numref:`Figure %s <fig-roc>` shows the internal
structure of Runtime Control for Aether, which has **x-config**\—a
microservice that maintains a set of YANG models—at its core.\ [#]_
x-config, in turn, uses Atomix (a Key/Value-Store microservice), to
make configuration state persistent. Because x-config was originally
designed to manage configuration state for devices, it uses gNMI as
its southbound interface to communicate configuration changes to
devices (or in our case, software services). An Adaptor has to be
written for any service/device that does not support gNMI
natively. These adaptors are shown as part of Runtime Control in
:numref:`Figure %s <fig-roc>`, but it is equally correct to view each
adaptor as part of the backend component, responsible for making that
component management-ready. Finally, Runtime Control includes a
Workflow Engine that is responsible for executing multi-step
operations on the data model. This happens, for example, when a change
to one model triggers some action on another model. Each of these
components are described in more detail in the next section.

.. [#] x-config is a general-purpose, model-agnostic tool. In AMP, it
       manages YANG models for cloud services, but it is also used by
       SD-Fabric to manage YANG models for a set of network switches
       and by SD-RAN to manage YANG models for a set of RAN elements.
       This means multiple instances of the x-config microservice run
       in a given Aether edge cluster.
       
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
consequence, Runtime Control can also mediate access to the other
subsystems of the Control and Management Platform (not just the
subsystems shown in :numref:`Figure %s <fig-roc>`).

This situation is illustrated in :numref:`Figure %s <fig-roc2>`, where
the key takeaway is that (1) we want RBAC and auditing for all
operations; (2) we want a single source of authoritative configuration
state; and (3) we want to grant limited (fine-grained) access to
management functions to arbitrary principals rather than assume that
only a single privileged class of operators. Of course, the private
APIs of the underlying subsystems still exist, and operators can
directly use them. This can be especially useful when diagnosing
problems, but for the three reasons given above, there is a strong
argument in favor of mediating all control activity using the Runtime
Control API.

This discussion is related to the “What About GitOps?”  question
raised at the end of Chapter 4. We return to that same question at the
end of this chapter, but to set the stage, we now have the option of
Runtime Control maintaining authoritative configuration and control
state for the system in its K/V store. This raises the question of how
to “share ownership” of configuration state with the repositories
that implement Lifecycle Management.

One option is to decide on a case-by-case basis: Runtime Control
maintains authoritative state for some parameters and the Config Repo
maintains authoritative state for other parameters. We just need to be
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
   :width: 450px
   :align: center

   Runtime Control also mediates access to the other Management
   Services.

Another aspect of :numref:`Figure %s <fig-roc2>` worth noting is
that, while Runtime Control mediates all control-related activity, it
is not in the “data path” for the subsystems it controls. This means,
for example, that monitoring data returned by the Monitoring & Logging
subsystem does not pass through Runtime Control; it is delivered
directly to dashboards and applications running on top of the
API. Runtime Control is only involved in authorizing access to such
data. It is also the case that Runtime Control and the Monitoring
subsystem have their own, independent data stores: it is the Atomix
K/V-Store for Runtime Control and a Time-Series DB for Monitoring (as
discussed in more detail in Chapter 6).

In summary, the value of a unified Runtime Control API is best
illustrated by the ability to implement closed-loop control
applications (and other dashboards) that "read" data collected by the
Monitoring subsystem; perform some kind of analysis on that data,
possibly resulting in a decision to take corrective action; and then
"write" new control directives, which x-config passes along to some
combination of SD-RAN, SD-Core, and SD-Fabric, or sometimes even to
the Lifecycle Management subsystem. (We'll see an example the latter
in Section 5.3.) This closed-loop scenario is depicted in
:numref:`Figure %s <fig-roc3>`, which gives a different perspective by
showing the Monitoring subsystem as a "peer" of Runtime Control
(rather than below it), although both perspectives are valid.

.. _fig-roc3:
.. figure:: figures/Slide17.png
   :width: 500px
   :align: center

   Another perspective of Runtime Control, illustrating the value of a
   unified API that supports closed-loop control applications.

5.2 Implementation Details
--------------------------

This section describes each of the components in Runtime Control,
focusing on the role each plays in cloud management.

5.2.1 Models & State
~~~~~~~~~~~~~~~~~~~~

x-config is the core of the Runtime Control. Its job is to store
and version configuration data. Configuration is pushed to x-config
through its northbound gNMI interface, stored in an persistent
Key/Value-store, and pushed to backend subsystems using a southbound
gNMI interface.

A collection of YANG-based models define the schema for this
configuration state. These models are loaded into x-config, and
collectively define the data model for all the configuration and
control state that Runtime Control is responsible for. As an example,
the data model (schema) for Aether is sketched in Section 5.3, but
another example would be the set of OpenConfig models used to manage
network devices.

There are four important aspects of this mechanism:

* **Persistent Store:** Atomix is the cloud native K/V-store used to
  persist data in x-config. Atomix supports a distributed map
  abstraction, which implements the Raft consensus algorithm to
  achieve fault-tolerance and scalable performance. x-config writes
  data to and reads data from Atomix using a simple GET/PUT interface
  common to NoSQL databases.
  
* **Loading Models:** A Kubernetes Operator (not shown in the figure),
  is responsible for configuring the models within x-config. Models
  to load into x-config are specified by a Helm chart. The operator
  compiles them on demand and incorporates them into x-config. This
  eliminates dynamic load compatibility issues that are a problem when
  models and x-config are built separately.
  
* **Versioning and Migration:** All the models loaded into x-config
  are versioned, and the process of updating those models triggers the
  migration of persistent state from one version of the data model to
  another. The migration mechanism supports simultaneous operation of
  multiple versions.

* **Synchronization:** It is expected that the backend components
  being controlled by x-config will periodically fail and restart.
  Since x-config is the runtime source-of-truth for those components,
  it takes responsibility for ensuring that they re-synchronize with
  the latest state upon restart. x-config is able to detect a restart
  (and trigger the synchronization) because its models include
  variables that reflect the operational state of those components.

Two points require further elaboration. First, because Atomix is
fault-tolerant as long as it runs on multiple physical servers, it can
be built on top of unreliable local (per-server) storage. There is no
reason to use highly available cloud storage. On the other hand,
prudence dictates that all the state the Runtime Control subsystem
maintains be backed up periodically, in case it needs to be restarted
from scratch due to a catastrophic failure. These checkpoints, plus
all the configuration-as-code files stored in GitHub, collectively
define the entirety of the authoritative state needed to
(re-)instantiate a cloud deployment.

Second, the set of model definitions are like any other piece of
configuration-as-code. They are checked into the code repository and
versioned, just as described in Section 4.5. Moreover, the Helm chart
that specifies how to deploy the Runtime Control subsystem identifies
the version of the models that are to be loaded, analogous to the way
Helm charts already identify the version of each microservice (Docker
Image) to be deployed. This means the version of the Runtime Control
Helm chart effectively specifies the version of the Runtime Control
API, since as we'll see in a the next subsection, that API is
auto-generated from the set of models. All of this is to say that
version control for the Northbound Interface of the cloud, as an
aggregated whole, is managed in exactly the same way as version control
for each functional building block that contributes to the cloud's
internal implementation.
  
5.2.2 Runtime Control API
~~~~~~~~~~~~~~~~~~~~~~~~~

An API provides an *interface wrapper* that sits between x-config and
higher-layer portals and applications. Northbound, it offers a RESTful
API. Southbound, it speaks gNMI to x-config. It is entirely possible
to auto-generate the REST API from the set of models loaded into
x-config, although one is also free to augment this set with
additional “hand-crafted” calls for the sake of convenience (although
typically this will mean the API is no longer RESTful).

The Runtime Control API layer serves multiple purposes:

* Unlike gNMI (which supports only **GET** and **SET** operations), a
  RESTful API (which supports **GET**, **PUT**, **POST**, **PATCH**,
  and **DELETE** operations)  is expected for GUI development.
  
* The API layer is an opportunity to implement early parameter
  validation and security checks. This makes it possible to catch
  errors closer to the user, and generate more meaningful error
  messages than is possible with gNMI.
  
* The API layer is an opportunity to implement semantic translation,
  adding methods that go beyond the auto-generated calls.

* The API layer defines a "gate" that can be used to audit the history
  of who performs what operation when (also taking advantage of the
  identity management mechanism described next).
  
5.2.3 Identity Management
~~~~~~~~~~~~~~~~~~~~~~~~~

Runtime Control leverages an external identity database (i.e. LDAP
server) to store user data such as account names and passwords for
users who are able to log in. This LDAP server also has the capability
to associate users with groups. For example, adding administrators to
the ``AetherAdmin`` group would be an obvious way to grant those
individuals with administrative privileges within Runtime Control.

An external authentication service, Keycloak, serves as a frontend to
a database like LDAP. It authenticates the user, handles the mechanics
of accepting the password, validating it, and securely returning the
group the user belongs to.

.. _reading_dex:
.. admonition:: Further Reading

   `Keycloak: Open Source Identity and Access Management
   <https://www.keycloak.org/>`__.

The group identifier is then used to grant access to resources within
Runtime Control, which points to the related problem of establishing
which classes of users are allowed to create/read/write/delete various
collections of objects. Like identity management, defining such RBAC
policies is well understood, and supported by open source tools. In
the case of Aether, Open Policy Agent (OPA) serves this role.

.. _reading_opf:
.. admonition:: Further Reading

   `Policy-based control for cloud native environments
   <https://www.openpolicyagent.org/>`__.


5.2.4 Adapters
~~~~~~~~~~~~~~

Not every service or subsystem beneath Runtime Control supports gNMI,
and in the case where it is not supported, an adapter is written to
translate between gNMI and the service’s native API. In Aether, for
example, a gNMI :math:`\rightarrow` REST adapter translates between
the Runtime Control’s southbound gNMI calls and the SD-Core
subsystem’s RESTful northbound interface. The adapter is not
necessarily just a syntactic translator, but may also include its own
semantic layer. This supports a logical decoupling of the models
stored in x-config and the interface used by the southbound
device/service, allowing the southbound device/service and Runtime
Control to evolve independently. It also allows for southbound
devices/services to be replaced without affecting the northbound
interface.

5.2.5 Workflow Engine
~~~~~~~~~~~~~~~~~~~~~

The workflow engine, to the left of the x-config in :numref:`Figure %s
<fig-roc>`, is where multi-step workflows are implemented. For
example, defining a new 5G connection or associating devices with an
existing connection is a multi-step process, using several models and
impacting multiple backend subsystems. In our experience, there may
even be complex state machines that implement those steps.

There are well-known open source workflow engines (e.g., Airflow), but
our experience is that they do not match up with the types of
workflows typical of systems like Aether. As a consequence, the
current implementation is ad hoc, with imperative code watching a
target set of models and taking appropriate action whenever they
change. Defining a more rigorous approach to workflows is a subject of
ongoing development.

5.2.6 Secure Communication
~~~~~~~~~~~~~~~~~~~~~~~~~~

gNMI naturally lends itself to mutual TLS for authentication, and that
is the recommended way to secure communications between components
that speak gNMI. For example, communication between x-config and
its adapters uses gNMI, and therefore, uses mutual TLS. Distributing
certificates between components is a problem outside the scope of
Runtime Control. It is assumed that another tool will be responsible
for distributing, revoking, and renewing certificates.

For components that speak REST, HTTPS is used to secure the
connection, and authentication can take place using mechanisms within
the HTTPS protocol (basic auth, tokens, etc). Oath2 and OpenID Connect
are leveraged as an authorization provider when using these REST APIs.

5.3 Modeling Connectivity Service
----------------------------------------

This section sketches the data model for Aether's connectivity service
as a way of illustrating the role Runtime Control plays. These models
are specified in YANG (for which we include a concrete example of one
of the models), but since the Runtime Control API is generated from
these specs, it is equally valid to think in terms of an API that
supports REST's GET, POST, PATCH, DELETE operations on a set of
objects (resources):

* GET: Retrieve an object.
* POST: Create an object.
* PUT,  PATCH: Modify an existing object.
* DELETE: Delete an object.

Each object is an instance of one of the YANG-defined models, where
every object contains an `id` field that is used to identify the
object. These identifiers are unique to the model, but not necessarily
across all models.

Some objects contain references to other objects. For example, many
objects contain references to the `Enterprise` object, which allows
them to be associated with a particular enterprise. That is,
references are constructed using the `id` field of the referenced
object. Note that one of the features of the mechanisms described in
the previous section is that they flag attempts to create a reference
to an object that does not exist and attempts to delete an object
while there are open references to it from other objects as errors.

In addition to the `id` field, several other fields are also common to
all models. These include:

* `description`: A human-readable description, used to store additional context about the object.
* `display-name`: A human-readable name that is shown in the GUI.

As these fields are common to all models, we omit them from the
per-model descriptions that follow. Note that we use upper case to
denote a model (e.g., `Enterprise`) and lower case to denote a field
within a model (e.g., `enterprise`).

5.3.1 Enterprises
~~~~~~~~~~~~~~~~~

Aether is deployed in enterprises, and so needs to define
representative set of organizational abstractions. These include
`Enterprise`, which forms the root of a customer-specific
hierarchy. The `Enterprise` model is referenced by many other objects,
and allows those objects to be scoped to a particular Enterprise for
ownership and role-based access control purposes. `Enterprise`
contains the following fields:

* `connectivity-service`: A list of backend subsystems that implement
  connectivity for this enterprise. Corresponds to an API endpoint to
  the SD-Core, SD-Fabric, and SD-RAN.

`Enterprises` are further divided into `Sites`. A site is a
point-of-presence for an `Enterprise` and may be either physical or
logical (i.e. a single geographic location could contain several
logical sites). `Site` contains the following fields:

* `enterprise`: A link to the `Enterprise` that owns this site.
* `imsi-definition`: A description of how IMSIs are constructed for
  this site. Contains the following sub-fields:

   * `mcc`: Mobile country code.
   * `mnc`: Mobile network code.
   * `enterprise`: A numeric enterprise id.
   * `format`: A mask that allows the above three fields to be
     embedded into an IMSI. For example `CCCNNNEEESSSSSS` will
     construct IMSIs using a 3-digit MCC, 3-digit MNC, 3-digit ENT,
     and a 6-digit subscriber.

The `imsi-definition` is specific to the mobile cellular network, and
corresponds to the unique identifier burned into every SIM card.

5.3.2 Connectivity Service
~~~~~~~~~~~~~~~~~~~~~~~~~~

Aether models 5G connectivity as a `Virtual Cellular Service (VCS)`,
which represents an isolated communication channel (and associated QoS
parameters) that connects a set of devices (modeled as a
`Device-Group`) to a set of applications (each of which is modeled as
an `Application`).  For example, an enterprise might configure one VCS
instance to carry IoT traffic and another to carry video traffic. The
`VCS` model has the following fields:

* `device-group`: A list of `Device-Group` objects that can participate in this `VCS`. Each
  entry in the list contains both the reference to the `Device-Group` as well as an `enable`
  field which may be used to temporarily remove access to the group.
* `application`: A list of `Application` objects that are either allowed or denied for this
  `VCS`. Each entry in the list contains both a reference to the `Application` as well as an
  `allow` field which can be set to `true` to allow the application or `false` to deny it.
* `template`: Reference to the `Template` that was used to initialize this `VCS`.
* `upf`: Reference to the User Plane Function (`UPF`) that should be used to process packets
  for this `VCS`. It's permitted for multiple `VCS` to share a single `UPF`.
* `enterprise`: Reference to the `Enterprise` that owns this `VCS`.
* `sst`, `sd`, `mbr.uplink`, `mbr.downlink`, `traffic-class`: Parameters that
  are initialized using a selected `template` (described below).

At one end of a VCS connection is a `Device-Group`, which identifies a
set of devices that are allowed to use the VCS connection.  The
`Device-Group` model contains the following fields:

* `imsis`: A list of IMSI ranges. Each range has the following
  fields:

   * `name`: Name of the range. Used as a key.
   * `imsi-range-from`: First subscriber in the range.
   * `imsi-range-to`: Last subscriber in the range. Can be omitted if
     the range only contains one IMSI.
* `ip-domain`: Reference to an `IP-Domain` object that describes the
  IP and DNS settings for UEs within this group.
* `site`: Reference to the site where this `Device-Group` may be
  used. Indirectly identifies the `Enterprise` as `Site` contains a
  reference to `Enterprise`.

At the other end of a VCS connection is a list of `Application`
objects, which specifies the endpoints for the program devices talk
to. The `Application` model contains the following fields:

* `address`: The DNS name or IP address of the endpoint.
* `endpoint`: A list of endpoints. Each has the following
  fields:

   * `name`: Name of the endpoint. Used as a key.
   * `port-start`: Starting port number.
   * `port-end`: Ending port number.
   * `protocol`:  Protocol (`TCP|UDP`) for the endpoint.
   * `mbr.uplink`, `mbr.downlink`: Maximum bitrate (mbr) for devices communicating with this
     application:
   * `traffice-class`: Traffic class for devices communicating with this application.

* `enterprise`: Link to an `Enterprise` object that owns this application. May be left empty
  to indicate a global application that may be used by multiple
  enterprises.

Anyone familiar with the 3GPP specification will recognize Aether's
*VCS* abstraction as similar to what cellular network calls a *slice*.
Much like the discussion about *subscribers* and *users* in the
introduction to this chapter, Aether elected to introduce neutral
terminology rather than reuse a term that comes with significant
implementation implications. The `VCS` model definition then includes
fields that record various implementation details, including `sst` and
`sd` (3GPP-defined identifiers for the slice) and `upf` (backend UPF
implementation for the Core's user plane). Although not yet part of
the production system, there is a version of `VCS` that also includes
fields related to RAN slicing, with the Runtime Control subsystem
responsible for stitching together end-to-end connectivity across the
RAN, Core, and Fabric.

.. sidebar:: An API for Platform Services

	*We are using Connectivity-as-a-Service as an illustrative
	example of the role Runtime Control plays, but APIs can be
	defined for other platform services using the same
	machinery. For example, because the SD-Fabric in Aether is
	implemented with programmable switching hardware, the
	forwarding plane is instrumented with Inband Network Telemetry
	(INT). A northbound API then enables fine-grain data
	collection on a per-flow basis, at runtime, making it possible
	to write closed-loop control applications on top of Aether.*

	*In a similar spirit, the QoS-related control example given in
	this section could be augmented with additional objects that
	provide visibility into, and an opportunity to exert control
	over, various radio-related parameters implemented by SD-RAN.
	Doing so would be a step towards a platform API that enables
	a new class of industry automation edge cloud apps.*

	*In general, Iaas and PaaS offerings need to support
	application- and user-facing APIs that go beyond the
	DevOps-level configuration files consumed by the underlying
	software components (i.e., microservices). Creating these
	interfaces is an exercise in defining a meaningful abstraction
	layer, which when done using declarative tooling, becomes an
	exercise in defining high-level data models. Runtime Control
	is the management subsystem responsible specifying and
	implementing the API for such an abstraction layer.*
	

5.3.3 QoS Profiles
~~~~~~~~~~~~~~~~~~

Associated with each VCS connection is a QoS-related profile that
governs how traffic that connection carries is to be treated. This
starts with a `Template` model, which defines the valid (accepted)
connectivity settings. Aether Operations is responsible for defining
these (the features they offer must be supported by the backend
subsystems), with enterprises selecting the template they want applied
to any instances of the connectivity service they create (e.g., via a
drop-down menu). That is, templates are used to initialize `VCS`
objects. The `Template` model has the following fields:

* `sst`, `sd`: Slice identifiers, as specified by 3GPP.
* `uplink`, `downlink`: Guaranteed uplink and downlink bandwidth.
* `traffic-class`: Link to a `Traffic-Class` object that describes the
  type of traffic.

As noted in the previous section, Aether decouples the abstract `VCS`
objects from the implementation details about the backend slices. One
reason for this decoupling is that it supports the option of spinning
up an entirely new copy of the SD-Core rather than sharing an existing
UPF with another VCS. This is done to ensure isolation, and
illustrates one possible touch-point between Runtime Control and the
Lifecycle Management subsystem: Runtime Control, via an Adaptor,
engages Lifecycle Management to launch the necessary set of Kubernetes
containers that implement an isolated slice.
  
The `Traffic-Class` model, in turn, specifies the classes of traffic,
and includes the following fields:

* `arp`: Allocation and retention priority.
* `qci`: QoS class identifier.
* `pelr`: Packet error loss rate.
* `pdb`: Packet delay budget.

For completeness, the following shows the corresponding YANG for the
`Template` model. The example omits some introductory boilerplate for
the sake of brevity. The example highlights the nested nature of the
model declarations, with both ``container`` and ``leaf`` fields.

.. literalinclude:: code/template.yang

5.3.4 Other Models
~~~~~~~~~~~~~~~~~~

The above description references other models, which we do not fully
described here. They include `AP-List`, which specifies a list of
access points (radios); `IP-Domain`, which specifies IP and DNS
settings; and `UPF`, which specifies the User Plane Function (the data
plane element of the SD-Core) that should forward packets on behalf of
this particular instance of the connectivity service. The `UPF` model
is necessary because Aether supports two different implementations:
one runs as a microservice on a server and the other runs as a P4
program loaded into the switching fabric, as described in a companion
book.

.. _reading_sdn:
.. admonition:: Further Reading 

   `Software-Defined Networks: A Systems Approach 
   <https://sdn.systemsapproach.org>`__

5.4 Revisiting GitOps
---------------------

As we did at the end of Chapter 4, it is instructive to revisit the
question of how to distinguish between configuration state and control
state, with Lifecycle Management (and its Config Repo) responsible for
the former, and Runtime Control (and its Key/Value store) responsible
for the latter. Now that we have seen the Runtime Control subsystem in
more detail, it is clear that one critical factor is whether or not a
programmatic interface (coupled with an access control mechanism) is
required for accessing and changing that state.

Cloud operators and DevOps teams are perfectly capable of checking
configuration changes into a Config Repo, which can make it tempting
to view all state that *could* be specified in a configuration file as
Lifecycle-managed configuration state. The availability of enhanced
configuration mechanisms, such as Kubernetes *Operators*, make that
temptation even greater. But any state that might be touched by
someone other than an operator—including enterprise admins and runtime
control applications—needs to be accessed via a well-defined API.
Giving enterprises the ability to set isolation and QoS parameters is
an illustrative example in Aether.  Auto-generating that API from a
set of models is an attractive approach to realizing such a control
interface, if for no other reason than it forces a decoupling of the
interface definition from the underlying implementation (with Adaptors
bridging the gap).

.. sidebar:: UX Considerations

    *Runtime control touches an important, but often under-appreciated
    aspect of operating a cloud: taking User Experience (UX) into
    account. If the only users you're concerned about are the
    developers and operators of the cloud and its services, who we can
    assume are comfortable editing a handful of YAML files to execute
    a change request, then maybe we can stop there. But if we expect
    end-users to have some ability to steer the system we're building,
    we also need to "plumb" the low-level variables we've implemented
    through to a set of dials and knobs that those users can access.*

    *UX Design is a well-established discipline. It is in part about
    designing GUIs with intuitive workflows, but a GUI depends on a
    programmatic interface. Defining that interface is the touchpoint
    between the mangement and control platform wer're focused on in
    this book, and the users we want to support. This is largely an
    exercise in defining abstractions, which brings us back to the
    central point we are trying to make: It is both the reality of the
    underlying implementation and the mental model of the target users
    that shape these abstractions. Considering one without the other,
    as anyone that has read a user's manual understands, is a recipe
    for disaster.*
    
On this latter point, it is easy to imagine an implementation of a
runtime control operation that involves checking a configuration
change into the Config Repo and triggering a redeployment. Whether you
view such an approach as elegant or clunky is a matter of taste, but
how such engineering decisions are resolved depends in large part on
how the backend components are implemented. For example, if a
configuration change requires a container restart, then there may be
little choice.  But ideally, microservices are implemented with their
own well-defined management interfaces, which can be invoked from
either a configuration-time Operator (to initialize the component at
boot time) or a control-time Adaptor (to change the component at
runtime).

For resource-related operations, like spinning up additional
containers in response to a user request to create a *Slice* or
activate an edge service, a similar implementation strategy is
feasible. The Kubernetes API can be called from either Helm (to
initialize a microservice at boot time) or from a Runtime Control
Adaptor (to add resources at runtime). The remaining challenge is
deciding which subsystem maintains the authoritative copy of that
state, and ensuring that decision is enforced as a system invariant.\ [#]_
Such decisions are often situation dependent, but our experience is
that using Runtime Control as the single source-of-truth is a sound
approach.

.. [#] It is also possible to maintain two authoritative copies of the
       state, and implement a mechanism to keep them in-sync. The
       difficulty with such a strategy is avoiding backdoor access
       that by-passes the synchronization mechanism.

Of course there are two sides to this coin. It is also tempting to
provide runtime control of configuration parameters that, at the end
of the day, only cloud operators need to be able to change.
Configuring the RBAC (e.g., adding groups and defining what objects a
given group is allowed to access) is an illustrative example. Unless
there is a compelling reason to open such configuration decisions to
end users, keeping RBAC-related configuration state (i.e., OPA spec
files) in the Config Repo, under the purview of Lifecycle Management,
makes complete sense.

These examples illustrate the central value proposition of the runtime
control interface, which is to scale operations. It does this by
enabling end users and closed-loop control programs to directly steer
the system without requiring that the ops team serve as an intermediary.

