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

This book lays out one roadmap that a small team of engineers followed
over a course of a year to stand-up and operationalize a hybrid cloud
spanning a dozen enterprises, and hosting a non-trivial cloud native
service (5G connectivity in our case, but that’s just an example). The
team was able to do this by leveraging 20+ open source components, but
selecting those components is just a start. There were dozens of
technical decisions to make along the way, and a few thousand lines of
configuration code to write. We believe this is a repeatable exercise,
which we report in this book. (And the code behind the book is open
source, for those that want to pursue the topic in more depth.)

Our roadmap may not be the right one for all circumstances, but it
does shine a light on the challenges and fundamental trade-offs
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
managing *services*. This makes it a topic everyone should know
something about.

| Larry Peterson, Scott Baker, Andy Bavier, Zack Williams, and Bruce Davie
| October 2021

