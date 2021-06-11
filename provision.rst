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

The process of racking and stacking hardware is inherently human
intensive, but for our purposes we focus on the wiring plan that the
technician uses as a blueprint. Our example based on a particular
scenario, Aether PODs deployed in enterprises, but it does serve to
highlight the required level of specificity.

3.3 Logical Infrastructure
--------------------------

Just as important as physically connecting the hardware, we need to
record a logical representation of that infrastructure, which the rest
of the management platform will need to do it's job. This practice is
sometimes called *infrastructure-as-code* since we will be
documenting, in a declarative format that other parts of the system
can "execute", exactly what our infrastructure looks like. A noble
goal, for sure, but one that is difficult to achieve in practice.

It turns out that the range of entities that either produce or consume
this information is wide enough that no single tool is sufficient.
There is low-level information related to how server ports are wired
and IP addresses assigned, and high-level information related to how
the OS is booted and other platform-level components are started. And
to complicate matters, this problem touches a "business office"
requirement of tacking physical inventory.

This section describes two such tools—NetBox and Terraform—along with
a set of scripts/playbooks we use in Aether to connect all the
dots. Before getting to those details, keep in mind this example is
focused on a physical cluster, but an analogous step would be required
to record how we are arranging virtual resources (e.g., VMs in AWS)
into a logical cluster. That problem is easier, though, because the
inventory half of the problem goes away.

NetBox: Low-Level Details
~~~~~~~~~~~~~~~~~~~~~~~~~

Terraform: High-Level Plans
~~~~~~~~~~~~~~~~~~~~~~~~~~~

3.4 Bootstrapping Hardware
--------------------------

Once physically connected and logically recorded, the next step is to
bootstrap the base software platform onto each server and switch. This
is the step we'd like to be as close to zero-touch as possible.


Management Network
~~~~~~~~~~~~~~~~~~

Servers
~~~~~~~

Switching Fabric
~~~~~~~~~~~~~~~~

VPN
~~~

Base Stations
~~~~~~~~~~~~~




