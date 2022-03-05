Chapter 6:  Monitoring and Logging
==================================

Collecting data about a running system, so that operators can evaluate
performance, make informed provisioning decisions, respond to
failures, identify attacks, and diagnose problems is an essential
function of any management platform. And correspondingly, there are
two widely used open source software stacks that address these
requirements for cloud deployments. That there are two (and not just
one) is indicative of how the problem space naturally divides into
two, mostly independent sub-problems: *monitoring* and *logging*.

The monitoring stack collects periodic quantitative data. These include
common performance metrics like link bandwidth, CPU utilization, and
memory usage, but also binary results corresponding to "up" and
"down". These values are produced and collected periodically (e.g.,
every few seconds), either by reading a counter, or by executing a
runtime test that returns a value.  These metrics can be associated
with physical resources like servers and switches, virtual resources
like VMs and containers, or high-level abstractions like the *Virtual
Celluar Service* described in Section 5.3. Given these many possible
sources of data, the job of the monitoring stack is to collect,
archive, visualize, and optionally analyze this data.

Clearly, the analysis step is open ended, and potentially includes
ML-based analytics. We characterize such sophisticated analysis as
running on top of the monitoring subsystem (and so outside the scope
of this discussion), and focus instead on simple examples like
watching for certain metrics to cross a threshold and triggering an
alert. Also note that there is a related problem of collecting usage
data for the sake of billing, but billing is typically handled using a
separate mechanism that must deliver a significantly higher level of
reliability, whereas occasionally dropping a monitoring value is not
especially harmful.

The logging stack collects qualitative data that is generated whenever
an unusual event occurs. This information can be used to identify
problematic operating conditions (i.e., it may trigger an alert), but
more commonly, it is used to troubleshoot problems after they have
been detected. Various system components—all the way from the
low-level OS kernel to high-level cloud services—write messages that
adhere to a well-defined format to the log. These messages include a
timestamp, which makes it possible for the logging stack to parse and
cross-reference message from different components.

Because both the metrics collected by the monitoring stack and the
event messages recorded by the logging stack are timestamped, it is
also possible to build linkages between the two subsystems, which is
especially helpful when debugging a problem or deciding whether an
alert is warranted. We give an example of how this and other useful
functions might be implemented in the following sections.

6.1 Monitoring and Alerts
-------------------------------

The standard open source monitoring stack uses Prometheus to collect
and store platform and service metrics, Grafana to visualize metrics
over time, and Alertmanager to notify the operations team of events
that require attention.  In Aether, Prometheus is instantiated on each
edge cluster, with a single instantiation of Grafana and Alertmanager
running centrally in the cloud. More information about each tool is
available online, so we focus more narrowly on (1) how individual
Aether components "opt into" this stack, and (2) how the stack can be
customized in service-specific ways.

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
other local variables to Prometheus, but only a "third-party observer"
can actively test external behavior, and report the results to
Prometheus. These examples correspond to the rightmost "End-to-End
Tests" shown in :numref:`Figure %s <fig-testing>` of Chapter 4.

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

Alerts for a particular component are defined by a *Prometheus Rule*,
an expression involving a Prometheus query, such that whenever it
evaluates to true for the indicated time period, triggers a
corresponding message to be routed to a set of receivers. These rules
are recorded in a YAML file that is checked into the Config Repo, and
then loaded into Alertmanager as a custom resource specified in the
corresponding Helm Chart. For example, the following code snippet
shows the Prometheus Rule for two alerts, where the ``expr`` lines
corresponds to the respective queries submitted to Prometheus.

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
adding a suite of scalable services. Today, the typical open source
logging stack uses Fluentd to collect (aggregate, buffer, and route)
log messages written by a set of components, with the Fluentbit
serving as client-side agent running in each component helping
developers normalize their log messages. ElasticSearch is then used to
store, search, and analyze those messages, with Kibana used to display
and visualize the results. The general flow of data is shown in
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
developed independent of each other. Fluentbit plays a role in
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

6.3 Integrated Dashboards
-------------------------

The monitoring and logging subsystems make it possible to collect a
wealth of data about the health of a system, but it's only useful if
the right data is displayed to the right people (those with the
ability to take action) at the right time (when action needs to be
taken). Creating useful panels and organizing them into intuitive
dashboards is part the solution, but integrating information across
the subsystems of the management platform is also a requirement.
This section highlights two examples.

First, while Kibana provides a dashboard view of the logs being
collected, in practice, it is most useful to have a convenient way to
see the log messages associated with a particular component (at a
particular time and log level) in the context of monitoring data. This
is easy to accomplish because Grafana can be configured to display
data from Elastic Search just as easily as from Prometheus. Both are
data sources that can be queried. This makes it to possible to create
a Grafana dashboard that includes a selected set of log messages,
similar to the one from Aether shown in :numref:`Figure %s
<fig-es_dash>`.  In this example, we see INFO-level messages
associated with the UPF sub-component of SD-Core, which augments the
UPF performance data shown in :numref:`Figure %s <fig-upf_dash>`.

.. _fig-es_dash:
.. figure:: figures/es_dash.png
   :width: 600px
   :align: center

   Log messages associated with the UPF element of SD-Core, displayed
   in a Grafana dashboard.

Second, the runtime control interface provides a means to change
various parameters of a running system, but having access to the data
needed to know what changes (if any) need to be made is a prerequisite
for making informed decisions. To this end, it is ideal to have access
to both the "knobs" and the "dials" on an integrated dashboard.  This
can be accomplished by incorporating Grafana frames in the Runtime
Control GUI, which in its simplest form, displays a set of web forms
corresponding to the fields in the underlying data models. (More
sophisticate control panels are certainly possible.)

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
