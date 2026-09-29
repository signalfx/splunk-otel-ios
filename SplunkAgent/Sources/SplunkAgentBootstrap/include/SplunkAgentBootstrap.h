/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#ifndef SPLUNK_AGENT_BOOTSTRAP_H
#define SPLUNK_AGENT_BOOTSTRAP_H

/// Link anchor used to keep the load-time bootstrap object in static products.
void splunk_rum_link_lifecycle_bootstrap(void);

#endif /* SPLUNK_AGENT_BOOTSTRAP_H */
