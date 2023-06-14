# Testing Templates

When creating supply chains and templates, it can be useful to test that the expected objects will be stamped by
Cartographer. To enable fast feedback, Cartographer has cartotest which can be used as a go testing framework or as a
cli test tool.

The approach of cartotest is to specify a template-workload pair under test. A supply chain may be supplied or mocked;
outputs from earlier steps in the supply chain may also be mocked. The object stamped is then compared to the provided
'expected' object. CompareOptions can be used to simplify the comparison (e.g. ignoring metadata fields of the stamped
object).

Read more:
- [Cartotest as a CLI](cartotest-cli.md)