# Usage

## Action 

Why do you buy a firewall in the first place??? to **block!**

Understanding what **action** your firewall took for each connection is the most relevant piece of information for security analysis. Every investigation starts here: "What did the firewall do?"

However, each firewall vendor has a different approach on how to undestand *action* and do they mean by it. 

It is a mixture of:

- what the configuration for that parituclar flow was
- how the connection ended
- whether there was a security flaw on that session

|    |Fortigate|Palo Alto|
|----|---------|---------|
|Fields| <ul><li>`action`: action taken by firewall policy, or if accepted, it refers to how the connection was closed.</li><li>`utmaction`: action took by the UTM engine, in case connection triggered at least of them.</li></ul>|<ul><li>`action`: action taken by firewall policy.</li><li>`threat/content_type`: action took by the security engine.</li><li>`session_end_reason`: how the session ended.</li></ul>|


<ul><li>`action`: action taken by firewall policy.</li><li>`threat/content_type`: action took by the security engine.</li><li>`session_end_reason`: how the session ended.</li></ul>

threat/content_type
action
session_end_reason

## Fortigate

![Action](../assets/dashboards/[Grafana] Fortigate Action.png)

Fortigate has 2 kind of actions:

- `action`: action taken by firewall policy, or if accepted, it refers to how the connection was closed.
- `utmaction`: action took by the UTM engine, in case connection triggered at least of them.

We combine the analysis of both in a , percentage, and absolute fashion. As well as dissecting `utmaction` into the UTM engines that influence it.

## Palo Alto


![Action](../assets/dashboards/[Grafana] Palo Alto Action.png)

Palo Alto 

(What the Firewall Did About It)

This is the core of everything.
Firewalls exist for one main reason: to take action.
Every connection that crosses the line gets one — allow, deny — and that decision defines your entire security posture.

In our dashboards, actions sit right under the global metrics because that’s where the truth lives.
If your “blocked” graph is flat and your “allowed” one looks like Mount Everest, that’s not visibility — that’s exposure.

We highlight firewall actions so you can instantly see what the system did, not just what it saw.


- metrics
- action
- dimensions & facts
