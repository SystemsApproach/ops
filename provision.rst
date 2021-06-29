Chapter 3:  Resource Provisioning
=================================
	
.. todo::
   
   Explain how to start with bare-metal and turn it into servers
   running Docker with Kubernetes. Describe NetBox and inventory
   management. Include an example wiring diagram, so we can
   connect-the-dots between the assumed hardware and resulting
   cloud.

   The current outline is loosely based on the “Edge Deployment”
   documentation.

3.1 Challenge
-------------

We start by scoping the problem we're trying to address. 

3.2 Physical Infrastructure
---------------------------

The process of stacking and racking hardware is inherently human
intensive, but for our purposes, we focus on the cabling plan that a
hands-on technician uses as a blueprint. The example shown in
:numref:`Figure %s <fig-cable_plan>`, which is based on Aether POD
deployed in enterprises, serves to highlight the required level of
specificity (including details about individual device models). We use
this as a running example throughout this chapter, to help illustrate all
the steps involved.

.. _fig-cable_plan:
.. figure:: figures/pronto_logical_diagram.png
    :width: 700px
    :align: center

    Example network cable plan for an edge cluster.

The goal is to minimize manual configuration required to bring up
physical infrastructure like that shown in :numref:`Figure %s
<fig-cable_plan>`, but *zero-touch* is a high bar. To illustrate, the
bootstrapping steps needed to complete provisioning for our example
POD currently includes:

* Configuring the Management Switch to know the set of VLANs being
  used.

* Configure the Management Server so it boots from a provided USB key.
  Install Ansible scripts needed to prep the Management Server to
  serve as the boot server for the Compute Servers.

* Configure the Compute Servers so they iPXE boot from the Management
  Server.

* Configure the Fabric Switches so they boot from the Management
  Server.

* Configure the eNBs (cellular base stations) so they know how their
  IP addresses. Various radio parameters can be set at this time, but
  they will become settable through the Management Platform once the
  POD is fully initialized.

The other general thing that needs to be done during the physical
install is record various parameters needed by later provisioning
steps. We postpone these details until they are relevant in later sections.

.. todo::
   
   Verify that the above list is relatively complete, keeping in mind
   that our goal is to logically connect-the-dots in the reader's mind
   (as opposed to serving as a full-blown recipe to be followed).

The actual rack mounting, of course, is manual, and includes
considerations such as airflow and cable management, but these issues
are beyond the scope of this book.

    
3.3 Logical Infrastructure
--------------------------

Just as important as physically connecting the hardware, we need to
record a logical representation of that infrastructure, which the rest
of the management platform will need to do it's job. This practice is
sometimes called *infrastructure-as-code* since we will be
documenting, in a declarative format that other parts of the system
can "execute", exactly what our infrastructure looks like.

It turns out that the range of entities that either produce or consume
this information is wide enough that no single tool is sufficient.
There is low-level information related to how server ports are wired
and IP addresses assigned, and high-level information related to how
the OS is booted and other platform-level components are started. And
to complicate matters, this problem touches a "business office"
requirement of tacking physical inventory.

This section describes two such tools—NetBox and Terraform—along with
a set of scripts/playbooks we use in Aether to connect all the dots.
Before getting to those details, keep in mind this example is focused
on a physical cluster, but an analogous step would be required to
record how we are arranging virtual resources (e.g., VMs in AWS) into
a logical cluster. That problem is easier, though, because the
inventory half of the problem goes away.

NetBox: Low-Level Details
~~~~~~~~~~~~~~~~~~~~~~~~~

.. todo::
   
   The following list is largely taken from the Site Install Guide,
   and is likely too detailed. Still need to determine how to best
   distill.

The point of this exercise is to record various low-level details
about the deployment. This is *site plan* recorded in NetBox as
follows:

.. _reading_netbox:
.. admonition:: Further Reading

   `NetBox <https://netbox.readthedocs.io/en/stable>`_

1. Add a Site for the edge (if one doesn't already exist), which has the
   physical location and contact information for the edge.

2. Add equipment Racks to the Site (if they don't already exist).

3. Add a Tenant for the edge (who owns/manages it), assigned to the ``Pronto``
   or ``Aether`` Tenant Group.

4. Add a VRF (Routing Table) for the edge site. This is usually just the name
   of the site.  Make sure that ``Enforce unique space`` is checked, so that IP
   addresses within the VRF are forced to be unique, and that the Tenant Group
   and Tenant are set.

5. Add a VLAN Group to the edge site, which groups the site's VLANs and
   requires that they have a unique VLAN number.

6. Add VLANs for the edge site.  These should be assigned a VLAN Group, the
   Site, and Tenant.

   There can be multiple of the same VLAN in NetBox (VLANs are layer 2, and
   local to the site), but not within the VLAN group.

   The minimal list of VLANs:

     * ADMIN 1
     * UPLINK 10
     * MGMT 800
     * FAB 801

   If you have multiple deployments at a site using the same management server,
   add additional VLANs incremented by 10 for the MGMT/FAB - for example:

     * DEVMGMT 810
     * DEVFAB 801

7. Add IP Prefixes for the site. This should have the Tenant and VRF assigned.

   All edge IP prefixes fit into a ``/22`` sized block.

   The description of the Prefix contains the DNS suffix for all Devices that
   have IP addresses within this Prefix. The full DNS names are generated by
   combining the first ``<devname>`` component of the Device names with this
   suffix.

   An examples using the ``10.0.0.0/22`` block. There are 4 edge
   prefixes, with the following purposes:

     * ``10.0.0.0/25``

        * Has the Server BMC/LOM and Management Switch
        * Assign the ADMIN 1 VLAN
        * Set the description to ``admin.<deployment>.<site>.aetherproject.net`` (or
          ``prontoproject.net``).

     * ``10.0.0.128/25``

        * Has the Server Management plane, Fabric Switch Management/BMC
        * Assign MGMT 800 VLAN
        * Set the description to ``<deployment>.<site>.aetherproject.net`` (or
          ``prontoproject.net``).

     * ``10.0.1.0/25``

        * IP addresses of the qsfp0 port of the Compute Nodes to Fabric switches, devices
          connected to the Fabric like the eNB
        * Assign FAB 801 VLAN
        * Set the description to ``fab1.<deployment>.<site>.aetherproject.net`` (or
          ``prontoproject.net``).

     * ``10.0.1.128/25``

        * IP addresses of the qsfp1 port of the Compute Nodes to fabric switches
        * Assign FAB 801 VLAN
        * Set the description to ``fab2.<deployment>.<site>.aetherproject.net`` (or
          ``prontoproject.net``).

   There also needs to be a parent range of the two fabric ranges added:

     * ``10.0.1.0/24``

        * This is used to configure the correct routes, DNS, and TFTP servers
          provided by DHCP to the equipment that is connected to the fabric
          leaf switch that the management server (which provides those
          services) is not connected to.

   Additionally, these edge prefixes are used for Kubernetes but don't need to
   be created in NetBox:

     * ``10.0.2.0/24``

        * Kubernetes Pod IP's

     * ``10.0.3.0/24``

        * Kubernetes Cluster IP's

8. Add Devices to the site, for each piece of equipment. These are named with a
   scheme similar to the DNS names used for the pod, given in this format::

     <devname>.<deployment>.<site>

   Examples::

     mgmtserver1.ops1.tucson
     node1.stage1.menlo

   Note that these names are transformed into DNS names using the Prefixes, and
   may have additional components - ``admin`` or ``fabric`` may be added after
   the ``<devname>`` for devices on those networks.

   Set the following fields when creating a device:

     * Site
     * Tenant
     * Rack & Rack Position
     * Serial number

   If a specific Device Type doesn't exist for the device, it must be created,
   which is detailed in the NetBox documentation, or ask the OPs team for help.

9. Add Services to the management server:

    * name: ``dns``
      protocol: UDP
      port: 53

    * name: ``tftp``
      protocol: UDP
      port: 69

   These are used by the DHCP and DNS config to know which servers offer
   DNS or TFTP service.

10. Set the MAC address for the physical interfaces on the device.

   You may also need to add physical network interfaces if  aren't already
   created by the Device Type.  An example would be if additional add-in
   network cards were installed.

11. Add any virtual interfaces to the Devices. When creating a virtual
    interface, it should have it's ``label`` field set to the physical network
    interface that it is assigned

    These are needed are two cases for the Pronto deployment:

     1. On the Management Server, there should bet (at least) two VLAN
        interfaces created attached to the ``eno2`` network port, which
        are used to provide connectivity to the management plane and fabric.
        These should be named ``<name of vlan><vlan ID>``, so the MGMT 800 VLAN
        would become a virtual interface named ``mgmt800``, with the label
        ``eno2``.

     2. On the Fabric switches, the ``eth0`` port is shared between the OpenBMC
        interface and the ONIE/ONL installation.  Add a ``bmc`` virtual
        interface with a label of ``eth0`` on each fabric switch, and check the
        ``OOB Management`` checkbox.

12. Create IP addresses for the physical and virtual interfaces.  These should
    have the Tenant and VRF set.

    The Management Server should always have the first IP address in each
    range, and they should be incremental, in this order. Examples are given as
    if there was a single instance of each device - adding additional devices
    would increment the later IP addresses.

      * Management Server

          * ``eno1`` - site provided public IP address, or blank if DHCP
            provided

          * ``eno2`` - 10.0.0.1/25 (first of ADMIN) - set as primary IP
          * ``bmc`` - 10.0.0.2/25 (next of ADMIN)
          * ``mgmt800`` - 10.0.0.129/25 (first of MGMT)
          * ``fab801`` - 10.0.1.1/25 (first of FAB)

      * Management Switch

          * ``gbe1`` - 10.0.0.3/25 (next of ADMIN) - set as primary IP

      * Fabric Switch

          * ``eth0`` - 10.0.0.130/25 (next of MGMT), set as primary IP
          * ``bmc`` - 10.0.0.131/25

      * Compute Server

          * ``eth0`` - 10.0.0.132/25 (next of MGMT), set as primary IP
          * ``bmc`` - 10.0.0.4/25 (next of ADMIN)
          * ``qsfp0`` - 10.0.1.2/25 (next of FAB)
          * ``qsfp1`` - 10.0.1.3/25

      * Other Fabric devices (eNB, etc.)

          * ``eth0`` or other primary interface - 10.0.1.4/25 (next of FAB)

13. Add DHCP ranges to the IP Prefixes for IP's that aren't reserved. These are
    done like any other IP Address, but with the ``Status`` field is set to
    ``DHCP``, and they'll consume the entire range of IP addresses given in the
    CIDR mask.

    For example ``10.0.0.32/27`` as a DHCP block would take up 1/4 of the ADMIN
    prefix.

14. Add router IP reservations to the IP Prefix for both Fabric prefixes. These
    are IP addresses used by ONOS to route traffic to the other leaf, and have
    the following attributes:

    - Have the last usable address in range (in the ``/25`` fabric examples
      above, these would be ``10.0.1.126/25`` and ``10.0.1.254/25``)

    - Have a ``Status`` of ``Reserved``, and the VRF, Tenant Group, and Tenant
      set.

    - The Description must start with the word ``router``, such as: ``router
      for leaf1 Fabric``

    - A custom field named ``RFC3442 Routes`` is set to the CIDR IP address of
      the opposite leaf - if the leaf's prefix is ``10.0.1.0/25`` and the
      router IP is ``10.0.1.126/25`` then ``RFC3442 Routes`` should be set to
      ``10.0.1.128\25`` (and the reverse - on ``10.0.1.254/25`` the ``RFC3442
      Routes`` would be set to be ``10.0.1.0/25``).  This creates an `RFC3442
      Classless Static Route Option <https://tools.ietf.org/html/rfc3442>`_
      for the subnet in DHCP.

15. Add Cables between physical interfaces on the devices, as
    specified in the Cabling Plan (:numref:`Figure %s
    <fig-cable_plan>`).  Note that many of the management interfaces
    need to be located either on the MGMT or ADMIN VLANs, and the
    management switch is used to provide that separation.

16.  The following inventory-related information should be recorded
     for every device:

    - Manufacturer
    - Model
    - Serial Number
    - MAC address (for the primary and any management/BMC/IPMI interfaces)

    The accuracy of this information is very important as it is used
    in bootstrapping the compute systems, which is currently done by
    Serial Number, as reported to iPXE by SMBIOS.

Once this data is entered, it is possible to generate a rack diagram,
similar to the one shown in :numref:`Figure %s <fig-rack_diagram>`
(which corresponds to the cabling diagram shown in :numref:`Figure %s
<fig-cable_plan>`. Note that the diagram show two logical PODs (one
running in Production and the other for Development), co-located in
one physical rack.

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
   

Terraform: High-Level Plans
~~~~~~~~~~~~~~~~~~~~~~~~~~~



