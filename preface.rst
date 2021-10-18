Preface
=======

.. admonition:: First Draft / Feedback Welcome
		
   This is a pre-release and still very much a work-in-progress.
   Please send us your comments and feedback using the `Issues Link
   <https://github.com/SystemsApproach/ops/issues>`__. See the `Wiki
   <https://github.com/SystemsApproach/ops/wiki>`__ for the latest
   todo list.

The cloud is ubiquitous. Everyone uses the cloud to either access or
deliver services, but not everyone will build a cloud. So why should
anyone care about how to turn a pile of servers and switches into a
24/7 service delivery platform? That's what Google, Microsoft, Amazon
and the other cloud providers do for us, and they do a perfectly good
job of it.

The answer, we believe, is that the cloud is becoming ubiquitous in
another way, as it moves from hundreds of datacenters to tens of
thousands of enterprises. And while it is clear that the commodity
cloud providers will happily manage those edge clusters as a logical
extension of their datacenters, they do not have a lock on the
know-how for making that happen.

This book lays out a roadmap that a small team of engineers followed
over a course of a year to stand-up and operationalize a hybrid cloud
spanning a dozen enterprises, and hosting a non-trivial cloud native
service (5G connectivity in our case, but that’s just an example). The
team was able to do this by leveraging 20+ open source components,
but selecting those components is just a start. There were dozens of
technical decisions to make along the way, and a few thousand lines of
configuration code to write. We believe this is a repeatable exercise,
which we report in this book. (And the code for those configuation
files is open source, for those that want to pursue the topic in more
detail.)

Our roadmap may not be the right one for all circumstances, but it
does shine a light on the fundamental challenges and trade-offs
involved in operationalizing a cloud. As we can attest based on our
experience, it’s a complicated design space with an overabundance of
terminology and storylines to untangle. Whether you plan to stand up
your own edge cloud in an enterprise, or end up selecting a cloud
provider to do that for you, understanding everything that goes into
such an endeavor is a critical first step in the decision making
process.

How to operationalize a computing system is a question that’s as old
as *Operating Systems*. Operationalizing a cloud is just today’s
version of that fundamental problem, which has become all the more
interesting as we move up the stack, from managing *devices* to
managing *services*. The fact that this topic is both timely and
rooted in the foundations of computing are among the reasons it is
worth studying.


Guided Tour of Open Source
--------------------------

The good news is that there is a wealth of open source components that
can be assembled to help manage cloud platforms and scalable
applications built on those platforms. That's also the bad news. With
several dozen cloud-related projects available at open source
consortia like the Linux Foundation, Apache Foundation, and Open
Networking Foundation, navigating the project space is one of the
biggest challenges we faced in putting together a cloud management
platform. This is in large part because these projects are competing
for mindshare, with significant overlap in the functionality they
offer.

One way to read this book is as a guided tour of the open source
landscape for cloud control and management. And in that spirit, we do
not replicate the fantastic documentation those projects already
provide. Our goal is to explain how the various puzzle pieces fit
together to build an end-to-end. We include links to project-specific
documentation, which often includes tutorials that we encourage you to
try.

Acknowledgements
------------------

The software described in this book is due to the hard work of the ONF
engineering team and the open source community that works with
them. We acknowledge their contributions, with a special thank-you to
Hyunsun Moon, Sean Condon, and HungWei Chiu for their significant
contributions to Aether's control and management platform, and to Oguz
Sunay for his influence on its overall design. We will also happily
thank, by name, anyone that provides feedback on early drafts of the
manuscript.

| Larry Peterson, Scott Baker, Andy Bavier, Zack Williams, and Bruce Davie
| October 2021

