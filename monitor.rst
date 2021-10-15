Chapter 6:  Monitoring and Logging
==================================

Collecting data about a running system, so that operators can evaluate
performance, make informed provisioning decisions, respond to
failures, identify attacks, and diagnose problems is an essential
function of many management platform. And correspondingly, there are
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
event message recorded by the logging stack are timestamped, it is
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

Individual components implement a *Prometheus Exporter* to expose
their metrics to Prometheus.  An exporter provides the current values
of a components's metrics via HTTP using a simple text format.
Prometheus scrapes the exporter's HTTP endpoint and stores the metrics
in its Time Series Database (TSDB) for querying and analysis.  Many
client libraries are available for instrumenting code to export
metrics in Prometheus format.  If a component's metrics are available
in some other format, tools are often available to convert the metrics
into Prometheus format and export them.

A component that exposes a Prometheus exporter HTTP endpoint via a
Service can tell Prometheus to scrape this endpoint by defining a
*ServiceMonitor*, a custom resource that is typically created by the
Helm Chart that installs the component.


6.1.2 Creating Dashboards
~~~~~~~~~~~~~~~~~~~~~~~~~

The metrics collected and stored by Prometheus running on each local
cluster are visualized centrally using Grafana dashboards.  In Aether,
this means the Grafana instance running as part of AMP in the central
cloud sends queries to the Prometheus instances running on all Aether
edge clusters.

Grafana comes with a set of pre-defined dashboards for the most common
set of metrics—in particular, those associated with physical servers
and virtual resources like containers—but it can also be customized to
include dashboards for service-level metrics and other
deployment-specific information (e.g., per-enterprise or per-cluster
in Aether).

Briefly, a dashboard is constructed from a set of *panels*, where each
panel has a well-defined *type* (e.g., graph, table, gauge, heatmap)
bound to a particular Prometheus *query*. New dashboards are created
using the Grafana GUI, and the resulting configuration then saved as a
JSON file. This configuration file is then committed to the
configuration repo, and later loaded into Grafana whenever is is
restarted as part of Lifecycle Management.

6.1.3 Defining Alerts
~~~~~~~~~~~~~~~~~~~~~

Alerts can be triggered in Prometheus when a component metric crosses
some threshold.  The Alertmanager then routes the alert to one or more
receivers, such as an email address or Slack channel.

Alerts for a particular component are defined by a *PrometheusRule*,
an expression involving a Prometheus query, such that whenever it
evaluates to true for the indicated time period, triggers a
corresponding message to be routed to a set of receivers. These rules
are recorded as a YAML file that is checked into the configuration
repo, and then loaded into Alertmanager as a custom resources
specified in the corresponding Helm Chart.

In Aether, the Alertmanager is configured to send alerts with
*critical* or *warning* severity to a general set of receivers.  If it
is desirable to route a specific alert to a different receiver (e.g.,
a component-specific Slack channel), one can change the Alertmanager
configuration accordingly.

6.2 Logging
------------------

The standard open source logging stack uses Fluentd to collect
(aggregate) log messages written by a set of components, with the
Fluentbit client-side library running in each component; ElasticSearch
to store, search, and analyze those messages; and Kibana to display
and visualize the results. The general flow of data is shown in
:numref:`Figure %s <fig-log>`.

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

The key challenge in logging is to adopt a uniform message format
across all components, a requirement that is complicated by the fact
that all the components integrated in a complex system are typically
developed independent of each other. Fluentbit plays a role in
normalizing these messages by supporting a set of filters. These
filters parse "raw" log messages written by the component (an ASCII
string), and output "canonical" log messages as structured JSON. In
the process, these filters also add globally-defined state, such as a
timestamp and a log level (e.g., ERROR, WARNING, INFO). For example,
developers for the SD-Fabric component might write a Fluentbit filter
that transforms

.. literalinclude:: code/log.ascii

into

.. literalinclude:: code/log.json

Note that this example is simplified, but it does serve to illustrate
the basic idea.
