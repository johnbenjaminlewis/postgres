name             'postgres'
maintainer       'Wanelo, Inc'
maintainer_email 'ops@wanelo.com'
license          'Apache 2.0'
description      'Installs/Configures postgres from sources, optimized for SmartOS, and ready for streaming replication'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '2.8.0'

supports 'smartos'

depends 'resource-control'
depends 'rbac'
depends 'smf', '>= 2.0.1'
depends 'ipaddr_extensions'
