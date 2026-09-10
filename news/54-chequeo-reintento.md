* The weekly layer check no longer reports a static file as down on a single
  404. Those files are regenerated periodically, and while they are being
  recreated they answer 404 even though the service is fine. The check now
  looks at the directory index first: if the file is still listed there, it is
  most likely being regenerated rather than withdrawn.
