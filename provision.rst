Chapter 3:  Resource Provisioning
=================================
	
.. todo::
   
   Explain how to start with bare-metal and turn it into servers
   running Docker with Kubernetes. Describe NetBox and inventory
   management. Include an example wiring diagram, so we can
   connect-the-dots between the assumed hardware and resulting
   cloud.



3.1 Challenge
-------------

.. todo::

   This section is not done. The goal is to scope the problem we're
   trying to address. This is also an opportunity to explain
   "provisioning the first time" versus "incremental provisioning".

   The general idea is to document, in a declarative format that other
   parts of the system can "execute", exactly what our infrastructure
   looks like. Introduce *infrastructure-as-code* but point out the
   problem is broad, including both (a) low-level information related
   to how server ports are wired and IP addresses assigned, and (b)
   high-level information related to how the OS is booted and other
   platform-level components are started. And to complicate matters,
   this problem touches a "business office" requirement of tacking
   physical inventory.

   Make the point that while this chapter starts with a physical
   cluster, an analogous step would be required to record how we are
   arranging virtual resources (e.g., VMs in AWS) into a logical
   cluster. That problem is easier, though, because the "low level"
   half of the problem goes away.

3.2 Physical Infrastructure 
---------------------------

The process of stacking and racking hardware is inherently human
intensive, and includes considerations such as airflow and cable
management. These issues are beyond the scope of this book.

We focus instead on the "physical/virtual" boundary, which starts with
the cabling plan that a hands-on technician uses as a blueprint. The
details of such a plan are highly deployment specific, but we use the
example shown in :numref:`Figure %s <fig-cable_plan>` to help
illustrate all the steps involved. The example is based on Aether PODs
deployed in enterprises, which serves to highlight the required level
of specificity (including details about individual device models).

.. _fig-cable_plan:
.. figure:: figures/pronto_logical_diagram.png
    :width: 700px
    :align: center

    Example network cable plan for an edge cluster.

In addition to following this blueprint, the technician also enters
various facts and parameters about the physical infrastructure into a
database. This information, which is used in later provisioning steps,
is where we pick up the story.

3.2.1 Document Infrastructure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Documenting the physical infrastructure involves both defining a model
(schema) for the information being collected, and entering the
corresponding facts into a database. It is familiar to anyone that is
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

   `NetBox <https://netbox.readthedocs.io/en/stable>`_

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
more *Deployments* (e.g,. a Deployment is a logical grouping of
resources, corresponding to, for example, ``Production``, ``Staging``,
and ``Development``).

This is also the time to specify the VLANs and IP Prefixes that are
assigned to this particular edge deployment of Aether. Because it is
important to maintain a clear relationship between VLANs, IP Prefixes,
and DNS names (the last of which are auto-generated), it is helpful to
walk through the following concrete example. We start with the minimal
set of VLANs needed per Site:

* ADMIN 1
* UPLINK 10
* MGMT 800
* FABRIC 801

If there are multiple Deployments at a Site sharing a single
management server, additional VLANs (incremented by 10 for
MGMT/FABRIC) are added; e.g.:

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

  * IP addresses of the qsfp0 port of the Compute Nodes to Fabric switches, devices
    connected to the Fabric like the eNB
  * Assign FABRIC 801 VLAN
  * Set the description to ``fab1.<deployment>.<site>.aetherproject.net``

* ``10.0.1.128/25``

  * IP addresses of the qsfp1 port of the Compute Nodes to fabric switches
  * Assign FABRIC 801 VLAN
  * Set the description to ``fab2.<deployment>.<site>.aetherproject.net``

For completeness, there are other edge prefixes used by Kubernetes but
do not need to be created in NetBox.
   
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
<fig-rack_diagram>` (which corresponds to the cabling diagram shown in
:numref:`Figure %s <fig-cable_plan>`. Note that the diagram show two
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
    :width: 500px
    :align: center

    NetBox report of cabling.    

Finally, if all of this seems like a tedious amount of detail, then
you get the main point of this section. Everything about automating
the control and management of a cloud hinges on having compete and
accurate data. Keeping this information in sync with the reality of
the physical infrastructure is often the weakest link in this process.

3.2.2 Manual Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In addition to installing the hardware and recording the relevant
facts about the installation, the other necessary step is to configure
the hardware so that it is "ready" for the automated procedures that
follow. The goal is to minimize manual configuration required to bring
up physical infrastructure like that shown in :numref:`Figure %s
<fig-cable_plan>`, but *zero-touch* is a high bar. To illustrate, the
bootstrapping steps needed to complete provisioning for our example
POD currently includes:

* Configuring the Management Switch to know the set of VLANs being
  used.

* Configure the Management Server so it boots from a provided USB key.

* Install Ansible scripts needed to prep the Management Server to
  serve as the boot server for the Compute Servers.

* Configure the Compute Servers so they iPXE boot from the Management
  Server.

* Configure the Fabric Switches so they boot from the Management
  Server.

* Configure the eNBs (cellular base stations) so they know their IP
  addresses. Various radio parameters can be set at this time, but
  they will become settable through the Management Platform once the
  POD is fully initialized.

In general, these manual configuration steps are limited to
"configuring the BIOS", such that any subsequent bootstrap steps can
be both fully automated and resilient.


3.3 Infrastructure-as-Code
--------------------------

All about Terraform, and the story behind GitOps and Infrastructure-as-Code...



