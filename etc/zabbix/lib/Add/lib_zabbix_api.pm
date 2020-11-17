package Add::lib_zabbix_api;
use strict;
use warnings;
use vars qw(@ISA);
use utf8;
use POSIX;
use Add::lib_config;
use Zabbix::Tiny;
use Config::JSON;
use Data::Dumper qw(Dumper);
#-------------------------------------------------------------------------------------------

sub new {
my $instance = shift;
my $class = ref($instance) || $instance;
my $self = {
     'Handle_Tiny'   => undef,      # Идентификатор объекта Zabbix::Tiny
     'Handle_config' => undef,      # Объект модуля работы с конфигурационным файлом
     'config_File'       => "",
     'zbx_system'        => "",
     'zbx_server'        => "",
     'zbx_username'      => "",
     'zbx_password'      => "",
    };
bless($self, $class);
return $self;
}
#-------------------------------------------------------------------------------------------

sub init {
my $self = shift;
my $conf_f = shift;
my $system = shift;

$self->{'config_File'} = $conf_f;
$self->{'zbx_server'}  = $system;

# 1. Грузим настройки
$self->{'Handle_config'}    = Add::lib_config->new( $self->{'config_File'} );

$self->{'zbx_server'}       = $self->{'Handle_config'}->get("$system/server","http://127.0.0.1/api_jsonrpc.php");
$self->{'zbx_username'}     = $self->{'Handle_config'}->get("$system/username","admin");
$self->{'zbx_password'}     = $self->{'Handle_config'}->get("$system/password","password");

# 2. Поднимаем соедиение
eval { 
  $self->{'Handle_Tiny'} = Zabbix::Tiny->new( server => $self->{'zbx_server'}, password => $self->{'zbx_password'}, user => $self->{'zbx_username'} );
  if ( defined $self->{'Handle_Tiny'} ) {
    return $self;
    }
  else {
    return undef;
    }
  };

if ($@) {
  return undef;
  }
}
#-------------------------------------------------------------------------------------------

sub get_users_list {
my $self = shift;
my %arr = ();
my $res = $self->{'Handle_Tiny'}->do( 'user.get', getAccess => 1, output => [ qw(users_status userid alias) ] );

if ( ( defined $res ) and ( $#$res >=0 ) ) {
  for my $y (@$res) {
    if ( ( defined $y->{alias} ) and
         ( defined $y->{userid} ) and
         ( defined $y->{gui_access} ) and
         ( defined $y->{debug_mode} ) and
         ( defined $y->{users_status} ) ) {
      my $alias = $y->{alias};
      $arr{user}{$alias}{userid}       = $y->{userid};
      $arr{user}{$alias}{gui_access}   = $y->{gui_access};
      $arr{user}{$alias}{debug_mode}   = $y->{debug_mode};
      $arr{user}{$alias}{users_status} = $y->{users_status};
      }
    }
  }
return %arr;
}
#-------------------------------------------------------------------------------------------

sub get_usergroup_list {
my $self = shift;
my %arr = ();
my $res = $self->{'Handle_Tiny'}->do( 'usergroup.get', output => [qw(usrgrpid name)], );

if ( ( defined $res ) and ( $#$res >=0 ) ) {
  for my $y (@$res) {
    if ( ( defined $y->{usrgrpid} ) and ( defined $y->{name} ) ) {
      $arr{usergroup}{ $y->{usrgrpid} } = $y->{name};
      }
    }
  }
return %arr;
}
#-------------------------------------------------------------------------------------------

sub get_usergroup_usrgrpid {
my $self      = shift;
my $usrgrpids = shift;
if ( ! defined $usrgrpids ) { 
  return undef;
  }

my %arr = ();
my $res = $self->{'Handle_Tiny'}->do( 'usergroup.get', usrgrpids => [ $usrgrpids ], selectUsers => 1,  output => [qw(userid name)], );
if ( ! defined $res ) {
  return undef;
  }

$res = shift @$res;
if ( ! defined $res ) {
  return undef;
  }

$res = $res->{users};
if ( ( defined $res ) and ( $#$res >=0 ) ) {
  for my $y ( @$res ) {
    #
    if ( defined $y->{userid} ) {
      $arr{ $y->{userid} } = 1;
      }
    }
  }
return \%arr;
}
#-------------------------------------------------------------------------------------------

sub get_user_usrgrpid {
my $self       = shift;
my $userid     = shift;
if ( ! defined $userid ) { 
  return undef;
  }
my %arr = ();
my $res = $self->{'Handle_Tiny'}->do( 'usergroup.get', userids=>$userid,  output => [ qw( usrgrps usrgrpid name) ], );
if ( ! defined $res ) {
  return undef;
  }
if ( $#$res == -1 ) {
  return undef;
  }
for my $y (@$res) {
  if ( ( defined $y->{usrgrpid} ) and ( defined $y->{name} ) ) {
    $arr{ $y->{usrgrpid} }{name} = $y->{name};
    }
  }
return %arr;
}
#-------------------------------------------------------------------------------------------

sub set_usergroup_usrgrpid {
my $self     = shift;
my $usrgrpid = shift;
my $userids  = shift;
if ( ( ! defined $usrgrpid ) or ( ! defined $userids ) ) { 
  return undef;
  }
my @userids = split(/ /,$userids,);
my $res = $self->{'Handle_Tiny'}->do( 'usergroup.update', usrgrpid => $usrgrpid , userids => [ @userids ],  );
}
#-------------------------------------------------------------------------------------------


1;