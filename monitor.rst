Chapter 6:  Monitoring and Telemetry
====================================

Collecting telemetry data for a running system, so that operators can
monitor its behavior, evaluate performance, make informed provisioning
decisions, respond to failures, identify attacks, and diagnose
problems is an essential function of any management platform. Broadly
speaking, there are three types of telemetry data—*metrics*, *logs*,
and *traces*\—with multiple open source software stacks available to
help collect, store, and act upon each of them.

Metrics are quantitative data about a system. These include common
performance metrics like link bandwidth, CPU utilization, and memory
usage, but also binary results corresponding to "up" and "down", as
well as other state variables that can be encoded numerically.  These
values are produced and collected periodically (e.g., every few
seconds), either by reading a counter, or by executing a runtime test
that returns a value.  These metrics can be associated with physical
resources like servers and switches, virtual resources like VMs and
containers, or high-level abstractions like the *Connectivity Service*
described in Section 5.3. Given these many possible sources of data,
the job of the metrics monitoring stack is to collect, archive,
visualize, and optionally analyze this data.

Logs are the qualitative data that is generated whenever an unusual
event occurs. This information can be used to identify problematic
operating conditions (i.e., it may trigger an alert), but more
commonly, it is used to troubleshoot problems after they have been
detected. Various system components—all the way from the low-level OS
kernel to high-level cloud services—write messages that adhere to a
well-defined format to the log. These messages include a timestamp,
which makes it possible for the logging stack to parse and
cross-reference message from different components.

Traces are a record of the sequence of modules executed to complete a
user-initiated transaction or job. They are similar to logs, but
provide more specialized information about the context in which
different operations are performed. Execution context is well-defined
in a single program, and is commonly recorded as an in-memory call
stack, but because we are operating in a cloud environment, traces are
inherently distributed across a graph of network-connected
microservices. This makes the problem challenging, but also critically
important because it is often the case that the only way to understand
a time-dependent phenomena—such as why a particular resource is over
loaded—is to understand how multiple independent workflows impact each
other.

.. sidebar:: Observability

    *Observability is a new term being used in the context monitoring,
    and while it is easily dismissed as the latest buzzword (which it
    is), it can also be interpretted as another of the set of "-ities"
    (qualities) that all good systems aspire to: scalability,
    reliability, availability, security, usability, and so on.
    Observability is the quality of system designed to reveal the
    facts (telemetry data) about its internal operation required to
    make informed management and control decisions. Instrumentation is
    the key implementation choice systems (and system components) make
    to improve their observability.*

    *Observability is not just a software quality. For example, a
    recent development is Inband Network Telemetry (INT), which takes
    advantage of programmable switching hardware to enable new
    questions about how network packets are being processed, rather
    than having to depend the fixed set of counters hardwired into
    network devices.  Because Aether uses programmable switches as the
    foundation for its SDN-based switching fabric, it has a fourth set
    of telemetry data availble to help debug problems, optimize
    performance, and detect malicious attacks. We do not discuss INT
    in this chapter, but refer the reader to our companion SDN book
    for more information.*

In addition to collecting various telemetry data, there is also an
analysis step required to take advantage of it. This is an open ended
problem, and potentially includes ML-based analytics. We characterize
such sophisticated analysis as running "on top of" the monitoring and
telemetry subsystem (and so outside the scope of this discussion), and
focus instead on (1) dashboards used to visualize the data, and (2)
simple examples like watching for certain metrics to cross a threshold
and triggering an alert. Also note that there is a related problem of
collecting usage data for the sake of billing, but billing is
typically handled using a separate mechanism that must deliver a
significantly higher level of reliability, whereas occasionally
dropping a monitoring value is not especially harmful.

Finally, because the metrics, logs, and traces collected by the
various subsystems are timestamped, it is also possible to build
linkages between them, which is especially helpful when debugging a
problem or deciding whether an alert is warranted. We give examples of
how this and other useful functions might be implemented in the
concluding section, where we also discuss ongoing efforts to unify
monitoring across all types of telemetry data.

6.1 Metrics and Alerts
-------------------------------

Starting with metrics, a popular open source monitoring stack uses
Prometheus to collect and store platform and service metrics, Grafana
to visualize metrics over time, and Alertmanager to notify the
operations team of events that require attention.  In Aether,
Prometheus and Alertmanager are instantiated on each edge cluster,
with a single instantiation of Grafana running centrally in the
cloud. More information about each tool is available online, so we
focus more narrowly on (1) how individual Aether components "opt into"
this stack, and (2) how the stack can be customized in
service-specific ways.

.. _reading_monitor:
.. admonition:: Further Reading

   `Prometheus <https://prometheus.io/docs/introduction/overview/>`__.

   `Grafana
   <https://grafana.com/docs/grafana/latest/getting-started/>`__.

   `Alertmanager <https://prometheus.io/docs/alerting/latest/alertmanager/>`__.


6.1.1 Exporting Metrics
~~~~~~~~~~~~~~~~~~~~~~~

Individual components implement a *Prometheus Exporter* to provide the
current value of the components's metrics. A component's Exporter is
queried via HTTP, with the corresponding metrics returned using a
simple text format. Prometheus periodically scrapes the Exporter's
HTTP endpoint and stores the metrics in its Time Series Database
(TSDB) for querying and analysis. Many client libraries are available
for instrumenting code to produce metrics in Prometheus format.  If a
component's metrics are available in some other format, tools are
often available to convert the metrics into Prometheus format and
export them.

A YAML configuration file specifies the set of Exporter endpoints that
Prometheus is to pull metrics from, along will the polling frequency
for each endpoint. Alternatively, Kubernetes-based microservices can
be extended with a *Service Monitor* custom resource that Prometheus
then queries to learn about any Exporter endpoints the microservice
has made available.

As an example of the latter, Aether runs a Service Monitor on every
edge cluster that periodically tests end-to-end connectivity (for
various definitions of end-to-end).  One test determines whether the
5G control plane is working (i.e., the edge site can reach the SD-Core
running in the central cloud) and a second test determines whether the
5G user plane is working (i.e., UEs can reach the Internet). This is a
common pattern: individual components can export accumulators and
other local variables, but only a "third-party observer" can actively
test external behavior, and report the results. These examples
correspond to the rightmost "End-to-End Tests" shown in
:numref:`Figure %s <fig-testing>` of Chapter 4.

Finally, when a system is running across multiple edge sites, as is
the case with Aether, there is an design question of whether
monitoring data is stored on the edge sites and lazily pulled to the
central location only when needed, or it is proactively pushed to the
central location as soon as it's generated. Aether employs both
approaches, depending on the volume and urgency of the data being
collected. By default, metrics collected by the local instantiation of
Prometheus stay on the edge sites, and only query results are returned
to the central location (e.g., to be displayed by Grafana as described
in the next subsection). This is appropriate for metrics that are both
high-volume and seldom viewed. The exception is the end-to-end Service
Monitors described in the previous paragraph. These results are
immediately pushed to the central site (by-passing Prometheus), which
works because they are low-volume and may require immediate attention.

6.1.2 Creating Dashboards
~~~~~~~~~~~~~~~~~~~~~~~~~

The metrics collected and stored by Prometheus running on each local
cluster are visualized centrally using Grafana dashboards.  In Aether,
this means the Grafana instance running as part of AMP in the central
cloud sends queries to the Prometheus instances running on all Aether
edge clusters. For example, :numref:`Figure %s <fig-ace_dash>` shows
the summary dashboard for a collection Aether edge sites.

.. _fig-ace_dash:
.. figure:: figures/ace_dash.png
   :width: 600px
   :align: center

   Central dashboard showing status of Aether edge deployments.

Grafana comes with a set of pre-defined dashboards for the most common
set of metrics—in particular, those associated with physical servers
and virtual resources like containers—but it can also be customized to
include dashboards for service-level metrics and other
deployment-specific information (e.g., per-enterprise in Aether). For
example, :numref:`Figure %s <fig-upf_dash>` shows a custom dashboard
for UPF (User Plane Function), the data plane packet forwarder of the
SD-Core. The example shows latency and jitter metrics over the last
hour at one site, with three additional collapsed panel (PFCP Sessions
and Messages) at the bottom.

.. _fig-upf_dash:
.. figure:: figures/upf_dash.png
   :width: 600px
   :align: center

   Custom dashboard showing latency and jitter metrics for UPF, the
   packet forwarding data plane of the SD-Core component.

Briefly, a dashboard is constructed from a set of *panels*, where each
panel has a well-defined *type* (e.g., graph, table, gauge, heatmap)
bound to a particular Prometheus *query*. New dashboards are created
using the Grafana GUI, and the resulting configuration then saved in a
JSON file. This configuration file is then committed to the Config
Repo, and later loaded into Grafana whenever is is restarted as part
of Lifecycle Management. For example, the following code snippet
shows the Prometheus query corresponding to the ``Uptime`` panel
in :numref:`Figure %s <fig-ace_dash>`.

.. literalinclude:: code/uptime.yaml

Note that this expression includes variables for the site (``$edge``)
and the interval over which the uptime is computed (``$__interval``).

6.1.3 Defining Alerts
~~~~~~~~~~~~~~~~~~~~~

Alerts can be triggered in Prometheus when a component metric crosses
some threshold.  Alertmanager is a tool that then routes the alert to
one or more receivers, such as an email address or Slack channel.

An alert for a particular component is defined by an *alerting rule*,
an expression involving a Prometheus query, such that whenever it
evaluates to true for the indicated time period, it triggers a
corresponding message to be routed to a set of receivers. These rules
are recorded in a YAML file that is checked into the Config Repo and
loaded into Prometheus. (Alternatively, Helm Charts for individual
components can define rules via *Prometheus Rule* custom resources.)
For example, the following code snippet shows the Prometheus Rule for
two alerts, where the ``expr`` lines corresponds to the respective
queries submitted to Prometheus.

.. literalinclude:: code/prometheus-rule.yaml

In Aether, the Alertmanager is configured to send alerts with
*critical* or *warning* severity to a general set of receivers.  If it
is desirable to route a specific alert to a different receiver (e.g.,
a Slack channel used by the developers for that particular component),
the Alertmanager configuration is changed accordingly.

6.2 Logging
------------------

OS programmers have been writing diagnostic messages to a *syslog*
since the earliest days of Unix. Originally collected in a local file,
the syslog abstraction has been adapted to cloud environments by
adding a suite of scalable services. Today, one typical open source
logging stack uses Fluentd to collect (aggregate, buffer, and route)
log messages written by a set of components, with Fluentbit serving as
client-side agent running in each component helping developers
normalize their log messages. ElasticSearch is then used to store,
search, and analyze those messages, with Kibana used to display and
visualize the results. The general flow of data is shown in
:numref:`Figure %s <fig-log>`, using the main Aether subsystems as
illustrative sources of log messages.

.. _fig-log:
.. figure:: figures/Slide23.png
   :width: 450px
   :align: center

   Flow of log messages through the Logging subsystem.

.. _reading_logging:
.. admonition:: Further Reading

   `Fluentd <https://docs.fluentd.org/>`__.

   `ElasticSearch
   <https://www.elastic.co/elasticsearch/>`__.

   `Kibana <https://www.elastic.co/kibana/>`__.

6.2.1 Common Schema
~~~~~~~~~~~~~~~~~~~

The key challenge in logging is to adopt a uniform message format
across all components, a requirement that is complicated by the fact
that the various components integrated in a complex system are often
developed independently of each other. Fluentbit plays a role in
normalizing these messages by supporting a set of filters. These
filters parse "raw" log messages written by the component (an ASCII
string), and output "canonical" log messages as structured JSON. There
are other options, but JSON is reasonably readable as text, which
still matters for debugging by humans. It is also well-supported by
tooling.

For example, developers for the SD-Fabric component might
write a log message that looks like this:

.. literalinclude:: code/log.ascii

where a Fluentbit filter transforms into a structure that looks like
this:

.. literalinclude:: code/log.json

This example is simplified, but it does serve to illustrate the basic
idea. It also highlights the challenge the DevOps team faces in
building the management platform, which is to decide on a meaningful
set of name/value pairs for the system as a whole. In other words,
they must define a common schema for these structured log messages.
The *Elastic Common Schema* is a good place to start that definition,
but among other things, it will be necessary to establish the accepted
set of log levels, and conventions for using each level. In Aether,
for example, the log levels are: FATAL, ERROR, WARNING, INFO, and
DEBUG.

.. _reading_ecs:
.. admonition:: Further Reading

   `Elastic Common Schema
   <https://www.elastic.co/guide/en/ecs/current/index.html>`__.


6.2.2 Best Practices
~~~~~~~~~~~~~~~~~~~~

Establishing a shared logging platform is, of course, of little value
unless all the individual components are properly instrumented to
write log messages. Programming languages typically come with library
support for writing log messages (e.g., Java's log4j), but that's just
a start. Logging is most effective if the components adhere to the
following set of best practices.

* **Log shipping is handled by the platform.** Components should
  assume that stdout/stderr is ingested into the logging system by
  Fluentbit (or similar tooling), and avoid making the job more
  complicated by trying to route their own logs.  The exception is for
  external services and hardware devices that are outside the
  management platform's control.  How these systems send their logs to
  a log aggregator must be established as a part of the deployment
  process.

* **File logging should be disabled.** Writing log files directly to a
  container's layered file system is proven to be I/O inefficient and
  can become a performance bottleneck. It is also generally
  unnecessary if the logs are also being sent to stdout/stderr.
  Generally, logging to a file is discouraged when a component runs in
  a container environment. Instead, components should stream all logs
  to the collecting system.

* **Asynchronous logging is encouraged.** Synchronous logging can
  become a performance bottleneck in a scaled environment.  Components
  should write logs asynchronously.

* **Timestamps should be created by the program's logger.** Components
  should use the selected logging library to create timestamps, with
  as precise of timestamp as the logging framework allows. Using the
  shipper or logging handlers may be slower, or create timestamps on
  receipt, which may be delayed. This makes trying to align events
  between multiple services after log aggregation problematic.

* **Must be able to change log levels without interrupting service.**
  Components should provide a mechanism to set the log level at
  startup, and an API that allows the log level to be changed at
  runtime. Scoping the log level based on specific subsystems is a
  useful feature, but not required. When a component is implemented by
  a suite of microservices, the logging configuration need only be
  applied to one instance for it to apply to all instances.

6.3 Distributed Tracing
-------------------------

The third tool in the monitoring toolkit is support for tracing, which
is challenging in a cloud setting because it involves following the
flow of control for each transaction across multiple microservices.
This makes it a distributed problem, rather than the simpler task of
inspecting an in-memory stack trace.

The general pattern is similar what we've already seen with metrics
and logs: the code is instrumented to produce data that is then
collected, aggregated, stored, and made available for display and
analysis. The main difference is the type of data we're interested in
collecting, which for tracing, is the sequence of API boundaries
crossings from one module to another. This data gives us the
information we need to reconstruct the call chain. In principle, we
could leverage one of the two systems we've already discussed to
support tracing—and just be diligent to produce the necessary
interface-crossing information—but it is a specialized enough use case
to warrant its own vocabulary, abstractions, and mechanisms.

At a high level, a *trace* is a description of a transaction as it
moves through the system. It consists of a sequence of *spans* (each
of which represents work done within a service) interleaved with a set
of *span contexts* (each of which represents the state carried across
the network from one service to another). If the terminology is a
little non-obvious, thinking of a trace as a directed graph, where the
nodes correspond to spans and the edges correspond to span contexts,
is a reasonable starting point. The nodes and edges are then
timestamped and annotated with relevant facts (key/value tags) about
the application. Importantly, each span includes timestamped log
messages generated while the span was executing (simplifying the
process of relating log messages with traces), and each span context
records the state (e.g., call parameters) that crosses microservice
boundaries.

Again, as with metrics and log messages, the details are important and
those details are specified by an agreed-upon data model. The
OpenTelemetry project is now defining one such model, building on the
earlier OpenTracing project. Notably, however, the problem is complex,
especially with respect to (1) reducing the overhead of tracing so as
to not negatively impact performance, and (2) extracting meaningful
high-level information from a collection of per-transaction traces. As
a consequence, distributed tracing is the subject of significant
ongoing research, and we can expect these definitions to evolve and
mature in the foreseeable future.

.. _reading_tracing:
.. admonition:: Further Reading

   `OpenTelemetry 
   <https://opentelemetry.io/>`__.

   `Jaeger: End-to-End Distributed Tracing 
   <https://www.jaegertracing.io/>`__.

With respect to mechanisms, Jaeger is a widely used open source
tracing tool originally developed by Uber. (Jaeger is not currently
included in Aether, but was utilized in a predecessor ONF edge cloud.)
Jaeger includes instrumentation of the runtime system for the
language(s) used to implement an application, a collector, storage, a
query language that can be used to analyze stored traces, and a user
dashboard designed to help diagnose performance problems and do root
cause analysis.

6.4 Integrated Dashboards
-------------------------

The metrics, logs and traces being generated by instrumented
application software make it possible to collect a wealth of data
about the health of a system. But this instrumentation is only useful
if the right data is displayed to the right people (those with the
ability to take action) at the right time (when action needs to be
taken). Creating useful panels and organizing them into intuitive
dashboards is part the solution, but integrating information across
the subsystems of the management platform is also a requirement.

Unifying all this data is the ultimate objective of on-going efforts
like the OpenTelemetry project mentioned in the previous section, but
there are also opportunities to use the tools described in this
chapter to better integrate data. This section highlights two
examples.

First, while Kibana provides a dashboard view of the logs being
collected, in practice, it is most useful to have a convenient way to
see the log messages associated with a particular component (at a
particular time and log level) in the context of metrics that have
been collected. This is easy to accomplish because Grafana can be
configured to display data from Elastic Search just as easily as from
Prometheus. Both are data sources that can be queried. This makes it
to possible to create a Grafana dashboard that includes a selected set
of log messages, similar to the one from Aether shown in
:numref:`Figure %s <fig-es_dash>`.  In this example, we see INFO-level
messages associated with the UPF sub-component of SD-Core, which
augments the UPF performance data shown in :numref:`Figure %s
<fig-upf_dash>`.

.. _fig-es_dash:
.. figure:: figures/es_dash.png
   :width: 600px
   :align: center

   Log messages associated with the UPF element of SD-Core, displayed
   in a Grafana dashboard.

Second, the runtime control interface described in Chapter 5 provides
a means to change various parameters of a running system, but having
access to the data needed to know what changes (if any) need to be
made is a prerequisite for making informed decisions. To this end, it
is ideal to have access to both the "knobs" and the "dials" on an
integrated dashboard.  This can be accomplished by incorporating
Grafana frames in the Runtime Control GUI, which in its simplest form,
displays a set of web forms corresponding to the fields in the
underlying data models. (More sophisticated control panels are
certainly possible.)

.. _fig-dev_group:
.. figure:: figures/gui1.png
   :width: 600px
   :align: center

   Example control dashboard showing the set of Device Groups defined
   for a fictional set of Aether sites.

For example, :numref:`Figure %s <fig-dev_group>` shows the current set
of device groups for a fictional set of Aether sites, where clicking
on the "Edit" button pops up a web form that lets the enterprise admin
modify the corresponding fields of the `Device-Group` model (not
shown), and clicking on the "Monitor" button pops up a
Grafana-generated frame similar to the one shown in :numref:`Figure %s
<fig-dev_monitor>`. In principle, this frame is tailored to show only
the most relevant information associated with the selected object.

.. _fig-dev_monitor:
.. figure:: figures/gui2.png
   :width: 600px
   :align: center

   Example monitoring frame associated with a selected Device Group.

