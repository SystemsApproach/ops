Preface
=======

The cloud is ubiquitous. Everyone uses the cloud to either access or
deliver services, but not everyone will build and operate a cloud. So
why should anyone care about how to turn a pile of servers and
switches into a 24/7 service delivery platform? That's what Google,
Microsoft, Amazon and the other cloud providers do for us, and they do
a perfectly good job of it.

The answer, we believe, is that the cloud is becoming ubiquitous in
another way, as distributed applications increasingly run not just in
large, central datacenters but at the edge. As applications are
disaggregated, the cloud is expanding from hundreds of datacenters to tens of
thousands of enterprises. And while it is clear that the commodity
cloud providers are eager to manage those edge clouds as a logical
extension of their datacenters, they do not have a monopoly on the
know-how for making that happen.

This book lays out a roadmap that a small team of engineers followed
over the course of a year to stand up and operationalize an edge cloud
and then operate it 24/7. This edge cloud spans a dozen
enterprises, and hosts a non-trivial cloud native service—5G
connectivity in our case, but that’s just an example. The team was
able to do this by leveraging 20+ open source components, but
selecting those components is just a start. There were dozens of
technical decisions to make along the way, and a few thousand lines of
configuration code to write. We believe this is a repeatable exercise,
which we report in this book. The code for those configuration
files is open source, for those who want to pursue the topic in more
detail.

What do we mean by an edge cloud? We're drawing a distinction between
clouds run by the hyperscale cloud providers in their massive data
centers, which we think of as the core, and those run by enterprises
(or managed for them) at the edge. The edge is where the real, physical
world meets the cloud. For example, it is the place where data from
sensors is likely to be gathered and processed, and where services
that need to be close to the end user for reasons of latency or
bandwidth are delivered.

Our roadmap may not be the right one for all circumstances, but it
does shine a light on the fundamental challenges and trade-offs
involved in operationalizing a cloud. As we can attest based on our
experience, it’s a complicated design space with an overabundance of
terminology and storylines to untangle.

Intended Audience
------------------

We hope this book makes valuable reading for anyone who is trying to
stand up and operationalize their own edge cloud infrastructure, but
we also aim to provide useful information for at least two other broad
groups.

First, there will be a set of readers who need to evaluate the
options available, particularly to decide between using the cloud
services offered by one of the hyperscalers or building their own edge
cloud (or some combination of these). We hope to demystify the
landscape of edge clouds for this audience to help inform those
decisions.

Secondly, there will be a group of application and service
developers who need to build on top of whatever cloud infrastructure
their organization has chosen to use. We believe it is important for
these developers to understand what goes on "under the hood" of the
cloud at least at a high level, so that they can make their
applications manageable and reliable. There is increasingly close
interaction between developers and operators (as evidenced by the
DevOps movement) and we aim to facilitate that collaboration. Topics
such as monitoring and observability are particularly important for
this audience.

Guided Tour of Open Source
--------------------------

The good news is that there is a wealth of open source components that
can be assembled to help manage cloud platforms and scalable
applications built on those platforms. That's also the bad news. With
several dozen cloud-related projects available at open source
consortia such as the Linux Foundation, Cloud Native Computing
Foundation, and Apache Foundation, navigating the project space is one
of the biggest challenges we faced in putting together a cloud
management platform. This is in large part because these projects are
competing for mindshare, with both significant overlap in the
functionality they offer and dependencies on each other.

One way to read this book is as a guided tour of the open source
landscape for cloud control and management. And in that spirit, we do
not replicate the excellent documentation those projects already
provide, but instead include links to project-specific documentation
(which often includes tutorials that we encourage you to try). We also
include snippets of code from those projects, but these examples are
chosen to help solidify the main points we're trying to make about the
management platform as a whole; they should not be interpreted as an
attempt to document the inner working of the individual projects. Our
goal is to explain how the various puzzle pieces fit together to build
an end-to-end management system, and in doing so, identify both
various tools that help and the hard problems that no amount of
tooling can eliminate.

It should come as no surprise that there are challenging technical
issues to address (despite marketing claims to the contrary). After
all, how to operationalize a computing system is a question that’s as
old as the field of *Operating Systems*. Operationalizing a cloud is
just today’s version of that fundamental problem, which has become all
the more interesting as we move up the stack, from managing *devices*
to managing *services*. This topic is both timely and
foundational.

Acknowledgements
------------------

The software described in this book is due to the hard work of the
Open Networking Foundation (ONF) engineering team and the open source
community that worked with them to build the *Aether* edge cloud.  We
acknowledge their contributions, with a special thank-you to Hyunsun
Moon, Sean Condon, and HungWei Chiu for their significant
contributions to Aether's control and management platform, and to Oguz
Sunay for his influence on Aether's overall design. Suchitra Vemuri's
insights into testing and quality assurance were also invaluable.

The ONF is no longer active, but Aether continues as an open source
project of the Linux Foundation. Visit https://aetherproject.org to
learn about the ongoing project. We will also happily accept feedback
to this book. Please send us your comments using the `Issues Link
<https://github.com/SystemsApproach/ops/issues>`__, or submit a Pull
Request with suggested changes.

| Larry Peterson, Scott Baker, Andy Bavier, Zack Williams, and Bruce Davie
| April 2025

