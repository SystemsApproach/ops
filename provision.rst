Chapter 3:  Resource Provisioning
=================================

Resource Provisioning is the process of bringing virtual and physical
resources online. It has both a hands-on component (installing devices
in a rack) and a bootstrap component (configuring how the resources
boot into a "ready" state). Resource Provisioning happens when a cloud
deployment is first installed—i.e., an initial set of resources are
provisioned—but also incrementally over time as new resources are
added, obsolete resources are removed, and out-of-date resources are
upgraded.

The goal of a Resource Provisioning is to be zero-touch, which is
impossible for hardware resources because it includes an intrinsically
manual step. (We'll take up the issue of provisioning virtual
resources in a moment.) Realistically, the goal is to minimize the
number and complexity of configuration steps required beyond
physically connecting the device, keeping in mind that we are starting
with commodity hardware received directly from a vendor, and not a
plug-and-play appliance that has been prepped.

When a cloud is built from virtual resources (e.g., VMs instantiated
on a commercial cloud) the "install" step for is carried out by
sequence of API calls rather a hands-on technician.  Of course, we
want to automate the sequence of calls needed to activate virtual
infrastructure, which has inspired an approach know as
*infrastructure-as-code*. The general idea is to document, in a
declarative format that can be "executed", exactly what our
infrastructure looks like. We use Terraform as our open source
approach to infrastructure-as-code.

When a cloud is built from a combination of virtual and physical
resources, as is the case for a hybrid cloud like like Aether, we need
a seamless way to accommodate both. To this end, our approach is to
first layer a *logical structure* on top of hardware resources, making
them roughly equivalent to the virtual resources we get from a
commercial cloud provider, resulting in a hybrid scenario similar to
the one shown in :numref:`Figure %s <fig-infra>`. We use NetBox as our
open source solution for constructing this logical structure on top of
physical hardware. NetBox also helps us address the requirement of
tracking physical inventory.

.. _fig-infra:
.. figure:: figures/Slide19.png
    :width: 450px
    :align: center

    Resource Provisioning in a hybrid cloud that includes both
    physical and virtual resources.

Note that the dotted arrow on the right in :numref:`Figure %s
<fig-infra>` is to indicate that Terraform does not interact directly
with NetBox via a well-defined API (as is the case on the left), but
instead with artifacts left behind by the hardware provisioning
process described in Section 3.1. One way to think about this that the
task of booting hardware into the "ready" state involves installing
and configuring several platform subsystems. It's these platform
subsystems that Terraform interacts with.

This chapter describes both sides of :numref:`Figure %s <fig-infra>`
starting with provisioning physical infrastructure. Our approach is to
focus on the challenge of provisioning an entire site the first
time. We comment on the simpler problem of incrementally provisioning
individual resources as relevant details emerge.


3.1 Physical Infrastructure 
---------------------------

The process of stacking and racking hardware is inherently human
intensive, and includes considerations such as airflow and cable
management. These issues are beyond the scope of this book.  We focus
instead on the "physical/virtual" boundary, which starts with the
cabling plan that a hands-on technician uses as a blueprint. The
details of such a plan are highly deployment specific, but we use the
example shown in :numref:`Figure %s <fig-cable_plan>` to help
illustrate all the steps involved. The example is based on Aether PODs
deployed in enterprises, which serves to highlight the required level
of specificity. Considerable planning is required to specify an
appropriate *Bill of Materials (BOM)*, including details about
individual device models, but this aspect of the problem space is
outside the scope of this book.

.. _fig-cable_plan:
.. figure:: figures/pronto_logical_diagram.png
    :width: 700px
    :align: center

    Example network cable plan for an edge cluster.

The blueprint shown in :numref:`Figure %s <fig-cable_plan>` actually
includes two logical clusters sharing a Management Switch and a
Management Server. The upper cluster corresponds to a production POD,
and includes five servers and a 2x2 leaf-spine switching fabric. The
lower cluster corresponds to a development POD, and includes two
servers and a single switch.

In addition to following this blueprint, the technician also enters
various facts and parameters about the physical infrastructure into a
database. This information, which is used in later provisioning steps,
is where we pick up the story.

3.1.1 Document Infrastructure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Documenting the physical infrastructure's logical structure in a
database is how we cross the physical-to-virtual boundary. It involves
both defining a set of models for the information being collected
(this schema effectively represents the logical structure shown in
:numref:`Figure %s <fig-infra>`), and entering the corresponding facts
about the physical devices. This process is familiar to anyone that is
responsible for managing a network of devices, whether it is the first
stage in a larger automated framework (such as the one described in
this book) or simply a place to record what IP address has been
assigned to each network appliance.

There are a plethora of open source tools available for the task. Our
choice is NetBox. It supports IP address management (IPAM);
inventory-related information about types of devices and where they
are installed; how infrastructure is organized (racked) by group and
site; and how devices are connected to consoles, networks, and power
sources. More information is readily available on the NetBox web site:

.. _reading_netbox:
.. admonition:: Further Reading

   `NetBox: <https://netbox.readthedocs.io/en/stable>`_ Information
   Resource Modeling Application.

One of the key features of NetBox is the ability to customize the set
of models used to organized all the information that is collected. For
example, an operator can define physical groupings like *Rack* and
*Site*, but also logical groupings like *Organization* and
*Deployment*.\ [#]_  In the following we use the Aether cable plan shown in
:numref:`Figure %s <fig-cable_plan>` as an illustrative example,
focusing on what happens when provisioning a single Aether site (but
keeping in mind that Aether spans multiple sites, as outlined in
Chapter 2).

.. [#] In this section, we will denote models in italics (e.g.,
       *Site*) and specific values assigned to an instance of a model
       as a constant (e.g., ``10.0.0.0/22``). Field names are not
       specially denoted, but they should be obvious from the context.
       
The first step is to create a record for the site being provisioned,
and documenting all the relevant metadata for that site. This includes
the *Name* and *Location* of the *Site*, along with the *Organization*
the site belongs to. An *Organization* can have more than one *Site*,
while a *Site* can (i) span one or more *Racks*, and (ii) host one or
more *Deployments*. A *Deployment* is a logical cluster,
corresponding, for example, to ``Production``, ``Staging``, and
``Development``. The cabling plan shown in :numref:`Figure %s
<fig-cable_plan>` includes two such deployments.

This is also the time to specify the VLANs and IP Prefixes assigned to
this particular edge deployment. Because it is important to maintain a
clear relationship between VLANs, IP Prefixes, and DNS names (the last
of which are auto-generated), it is helpful to walk through the
following concrete example. We start with the minimal set of VLANs
needed per Site:

* ADMIN 1
* UPLINK 10
* MGMT 800
* FABRIC 801

Of course, these are Aether-specific, but they are representative of
VLANs a cluster typically needs. Also, if there are multiple
Deployments at a Site sharing a single management server, additional
VLANs (incremented by 10 for MGMT/FABRIC) are added. For example:

* DEVMGMT 810
* DEVFABRIC 811

IP Prefixes are then associated with VLANs, with all edge IP prefixes
fitting into a ``/22`` sized block. This block is then partitioned in
a way that works in concert with how DNS names are managed (i.e.,
names are generated by combining the first ``<devname>`` component of
the *Device* names (see below) with this suffix. Using ``10.0.0.0/22``
as an example, there are four edge prefixes, with the following
purposes:

* ``10.0.0.0/25``

  * Has the Management Server and Management Switch
  * Assign the ADMIN 1 VLAN
  * Set the description to ``admin.<deployment>.<site>.aetherproject.net``

* ``10.0.0.128/25``

  * Has the Server Management plane, Fabric Switch Management
  * Assign MGMT 800 VLAN
  * Set the description to ``<deployment>.<site>.aetherproject.net``

* ``10.0.1.0/25``

  * IP addresses of the ``qsfp0`` port of the Compute Nodes to Fabric switches, devices
    connected to the Fabric like the eNB
  * Assign FABRIC 801 VLAN
  * Set the description to ``fab1.<deployment>.<site>.aetherproject.net``

* ``10.0.1.128/25``

  * IP addresses of the ``qsfp1`` port of the Compute Nodes to fabric switches
  * Assign FABRIC 801 VLAN
  * Set the description to ``fab2.<deployment>.<site>.aetherproject.net``

For completeness, there are other edge prefixes used by Kubernetes but
do not need to be created in NetBox. Note that ``qsfp0`` and ``qsfp1``
in this example denotes a transceiver ports connecting the switching
fabric; *QSFP* stand for Quad (4-channel) Small Form-factor Plugable.
   
With this site-wide information recorded, the next step is to install
and document each *Device*. This includes entering a ``<devname>``,
which is subsequently used to generate a fully qualified domain name
for the device: ``<devname>.<deployment>.<site>``. The following
fields are also filled in when creating a Device:

* Site
* Rack & Rack Position
* Manufacturer 
* Model 
* Serial number
* Device Type
* MAC Addresses
  
Note there is typically both a primary and management (e.g., BMC/IPMI)
interface, where the *Device Type* implies the specific interfaces.

Finally, the virtual interfaces for the Device must be specified, with
it's ``label`` field set to the physical network interface that it is
assigned. IP addresses are then assigned to the physical and virtual
interfaces we have defined. The Management Server should always have
the first IP address in each range, and they should be incremental, as
follows:

* Management Server

  * ``eno1`` - site provided public IP address, or blank if DHCP provided
  * ``eno2`` - 10.0.0.1/25 (first of ADMIN) - set as primary IP
  * ``bmc`` - 10.0.0.2/25 (next of ADMIN)
  * ``mgmt800`` - 10.0.0.129/25 (first of MGMT)
  * ``fab801`` - 10.0.1.1/25 (first of FABRIC)

* Management Switch

  * ``gbe1`` - 10.0.0.3/25 (next of ADMIN) - set as primary IP

* Fabric Switch

  * ``eth0`` - 10.0.0.130/25 (next of MGMT), set as primary IP
  * ``bmc`` - 10.0.0.131/25

* Compute Server

  * ``eth0`` - 10.0.0.132/25 (next of MGMT), set as primary IP
  * ``bmc`` - 10.0.0.4/25 (next of ADMIN)
  * ``qsfp0`` - 10.0.1.2/25 (next of FABRIC)
  * ``qsfp1`` - 10.0.1.3/25

* Other Fabric devices (eNB, etc.)

  * ``eth0`` or other primary interface - 10.0.1.4/25 (next of FABRIC)

Once this data is entered into NetBox, it is possible to generate a
rack diagram, similar to the one shown in :numref:`Figure %s
<fig-rack_diagram>`, which corresponds to the cabling diagram shown in
:numref:`Figure %s <fig-cable_plan>`. Note that the diagram shows two
logical *Deployments* (``Production`` and ``Development``), co-located
in one physical rack.

.. _fig-rack_diagram:
.. figure:: figures/rack_diagram.png
    :width: 500px
    :align: center

    NetBox rendering of rack configuration.

It is also possible to generate other useful specifications for the
POD, helping the technician confirm the recorded logical specification
matches the actual physical representation. For example,
:numref:`Figure %s <fig-cable_list>` shows the set of cables and how
they connect the set hardware in our example deployment.

.. _fig-cable_list:
.. figure:: figures/cable_list.png
    :width: 700px
    :align: center

    NetBox report of cabling.    

Finally, if all of this seems like a tedious amount of detail, then
you get the main point of this section. Everything about automating
the control and management of a cloud hinges on having compete and
accurate data about its resources. Keeping this information in sync
with the reality of the physical infrastructure is often the weakest
link in this process. The only saving grace is that the information is
highly structured, and the tool we use (NetBox) helps us codify this
structure.

3.1.2 Configure and Boot
~~~~~~~~~~~~~~~~~~~~~~~~

In addition to installing the hardware and recording the relevant
facts about the installation, the other necessary step is to configure
the hardware so that it is "ready" for the automated procedures that
follow. The goal is to minimize manual configuration required to
onboard physical infrastructure like that shown in :numref:`Figure %s
<fig-cable_plan>`, but *zero-touch* is a high bar. To illustrate, the
bootstrapping steps needed to complete provisioning for our example
POD currently includes:

* Configuring the Management Switch to know the set of VLANs being
  used.

* Configure the Management Server so it boots from a provided USB key.
  
* Load Ansible roles and playbooks needed to complete configuration
  onto Management Server.

* Configure the Compute Servers so they iPXE boot from the Management
  Server.

* Configure the Fabric Switches so they boot from the Management
  Server.

* Configure the eNBs (cellular base stations) so they know their IP
  addresses. Various radio parameters can be set at this time, but
  they will become settable through the Management Platform once the
  POD is fully initialized.

These are all manual configuration steps, requiring either console
access or entering information into device web interface, such that
any subsequent configuration steps can be both fully automated and
resilient.

As for these subsequent steps, they can be implemented as a set of
Ansible *roles* and *playbooks*, which in terms of the high-level
overview shown in :numref:`Figure %s <fig-provision>` of Chapter 2,
corresponds to the box representing the *"Zero-Touch Provision
(System)"*. Said another way, there is no off-the-shelf ZTP solution
we can use (i.e., someone has to write the playbooks), but the problem
is greatly simplified by having access to all the configuration
parameters maintained by NetBox.

The general idea is straightforward. For every network service (e.g.,
DNS, DHCP) and every kernel-level OS component (e.g., network
interfaces) that needs to be configured, there is a corresponding
Ansible role and playbook (i.e., script) that gets executed.\ [#]_
This set is copied onto the Management Server during the manual
configuration stage summarized above. In many cases, the playbooks use
specific parameters—such as VLANs, IP addresses, DNS names, and so
on—extracted from NetBox.

.. [#] We gloss over the distinction between *roles* and *playbooks*
       in Ansible, and focus on the general idea of there being a
       script that runs with a set of input parameters.

:numref:`Figure %s <fig-ansible>` illustrates the overall approach,
and fills in a few details. For example, a home-grown Python program
(``edgeconfig.py``) extracts data from NetBox and outputs a
corresponding set of YAML files, crafted to serve as input to yet
another open source tool (*Netplan*), which actually does the detailed
work of configuring the network subsystem on the various backend
devices (each with its own unique configuration syntax). The end
result is that all the hardware in a given physical POD is up and
running, ready for further instructions from the next layer of the
provisioning stack, as we now describe.

.. _fig-ansible:
.. figure:: figures/Slide20.png
    :width: 600px
    :align: center

    Configuring OS-level subsystems (e.g., network interfaces) using
    NetBox data.

More information about Ansible and Netplan is available on their
respective web sites:

.. _reading_ansible:
.. admonition:: Further Reading

   `Ansible: <https://www.ansible.com/>`_ Automation Platform.

   `Netplan: <https://netplan.io>`_ Network Configuration Abstraction Renderer.


3.2 Infrastructure-as-Code
--------------------------

All about Terraform, and the story behind GitOps and Infrastructure-as-Code...



