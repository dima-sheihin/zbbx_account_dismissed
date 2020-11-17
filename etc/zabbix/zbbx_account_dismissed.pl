#!/usr/bin/perl

use strict;
use warnings;
use vars qw(@ISA);
use utf8;
use POSIX;
use Sys::Syslog;

use lib '/etc/zabbix/lib';
use Data::Dumper qw(Dumper);

use Add::lib_zabbix_api;
use Net::LDAP;

# apt-get install libjson-perl
# apt-get install libnet-ldap-perl

my %work;
$work{zbbx}{group}{deactivated}{name} = "_Disabled";
$work{zbbx}{group}{deactivated}{id}   = undef;

$work{ad}{connecting}{dc}    = "dc.ххх.ru";
$work{ad}{connecting}{user}  = "CN=хххххххх,OU=ххххх,OU=ххх,OU=ххх,DC=хх,DC=ru";
$work{ad}{connecting}{pass}  = "yyyyyyyyy";
$work{ad}{connecting}{base}  = "OU=ххх,DC=хх,DC=ru";
$work{ad}{connecting}{scope} = "sub";


my $Handle_zabbix = Add::lib_zabbix_api->new();
if ( ! defined $Handle_zabbix ) {
  syslog("info", "Ошибка при иницализации lib_zabbix_api->new() скрипт завершает свою работу" );
  print "fatal, exit, read syslog\n";
  exit;
  }

my $res = $Handle_zabbix->init( "/etc/zabbix/zbbx_main.conf" , "zabbix" );
if ( ! defined $res ) {
  syslog("info", "Ошибка при иницализации init Zabbix API скрипт завершает свою работу" );
  print "fatal, exit, read syslog\n";
  exit;
  }

if ( ( ! defined $work{ad}{connecting}{dc} ) or
     ( ! defined $work{ad}{connecting}{user} ) or
     ( ! defined $work{ad}{connecting}{pass} ) or
     ( ! defined $work{ad}{connecting}{base} ) or
     ( ! defined $work{ad}{connecting}{scope} ) ) {
  syslog("info", "Ошибка не все параметры AD установлены" );
  print "fatal, exit, read syslog\n";
  exit;
  }

my $ldap = Net::LDAP->new ( "$work{ad}{connecting}{dc}" );
if ( ! defined $ldap ) {
  syslog("info", "Ошибка при иницализации ldap  Net::LDAP->new $work{ad}{connecting}{dc} скрипт завершает свою работу" );
  print "fatal, exit, read syslog\n";
  exit;
  }

my $mesg = $ldap->bind ( version => 3 );
if ( ! defined $mesg ) {
  syslog("info", "Ошибка при иницализации mesg  bind version => 3 скрипт завершает свою работу" );
  print "fatal, exit, read syslog\n";
  exit;
  }

$mesg = $ldap->bind ( $work{ad}{connecting}{user} , password => $work{ad}{connecting}{pass} , version => 3 );
if ( ( ! defined $mesg ) or ( ! defined $ldap ) ) {
  syslog("info", "Ошибка при иницализации ldap и пользователя $work{ad}{connecting}{user} " );
  print "fatal, exit, read syslog\n";
  exit;
  }

my %zbbx_user = $Handle_zabbix->get_users_list();
if ( scalar keys %{ $zbbx_user{user} } == 0 ) {
  syslog("info", "Ошибка нет ни одного пользователя из забикса" );
  print "fatal, exit, read syslog\n";
  exit;
  }


my %zbbx_usergroup = $Handle_zabbix->get_usergroup_list();
if ( scalar keys %{ $zbbx_usergroup{usergroup} } == 0 ) {
  syslog("info", "Ошибка нет ни одной пользовательской группы забикса" );
  print "fatal, exit, read syslog\n";
  exit;
  }


# print Dumper \%zbbx_user;
# {
# 'user' => {
#            'user1' => {
#                        'userid' => '20',
#                        'gui_access' => '0',
#                        'debug_mode' => '0',
#                        'users_status' => '0'
#                       },
#            'user2' => {
#                        'userid' => '37'
#                        'gui_access' => '0',
#                        'debug_mode' => '0',
#                        'users_status' => '0',
#                       },
#           }
# }

# gui_access   0 - (по умолчанию) использование метода аутентификации системы по умолчанию
#              1 - использование внутренней аутентификации
#              2 - использование LDAP аутентификации
#              3 - деактивация доступа к веб-интерфейсу
#
# debug_mode   0 - режим отладки деактивирован
#              1 - режим отладки активирован
#
# users_status 0 - пользователь активирован
#              1 - пользователь деактивирован

foreach my $usrgrpid ( keys %{ $zbbx_usergroup{usergroup} } ) {
  if ( ( defined $work{zbbx}{group}{deactivated}{name} )  and ( $work{zbbx}{group}{deactivated}{name} eq $zbbx_usergroup{usergroup}{$usrgrpid} ) ) {
    $work{zbbx}{group}{deactivated}{id}    = $usrgrpid;
    # Загрузим всех пользователей которые уже находятся в группе
    $work{zbbx}{group}{deactivated}{users} = $Handle_zabbix->get_usergroup_usrgrpid( $usrgrpid );
    }
  }

foreach my $alias ( keys %{ $zbbx_user{user} } ) {
  if ( ( $zbbx_user{user}{$alias}{gui_access} == 0 ) or ( $zbbx_user{user}{$alias}{gui_access} == 3 ) ) {

    my $result = undef;
    $result = $ldap->search ( base => $work{ad}{connecting}{base} , 
                              scope => $work{ad}{connecting}{scope} ,
                              filter => "(&(objectClass=user)(sAMAccountName=$alias))",
                              attrs => [ 'sAMAccountName' , 'userAccountControl' ] );

    if ( ( defined $result ) and ( defined $result->entries ) ) {
      my @entries = $result->entries;
      if ( $#entries >= 0 ) {
        foreach my $entr ( @entries ) {
          if ( ( defined $entr ) and ( defined $entr->attributes ) ) {
            foreach my $attr ( $entr->attributes ) {
              next if ( $attr =~ /;binary$/ );
              my $value = $entr->get_value ( $attr );
              if ( $attr eq 'sAMAccountName'     ) { $zbbx_user{user}{$alias}{ad}{samaccountName}     = $value; }
              if ( $attr eq 'userAccountControl' ) { $zbbx_user{user}{$alias}{ad}{userAccountControl} = $value; }
              }
            }
          }
        }
      }


    }
  }

# print Dumper \%zbbx_user;
# {
# 'user' => {
#            'user1' => {
#                        'userid' => '20',
#                        'gui_access' => '0',
#                        'debug_mode' => '0',
#                        'users_status' => '0'
#                        'ad' => {
#                                 'userAccountControl' => '514'
#                                 'samaccountName' => 'user1',
#                                },
#
#                       },
#            'user2' => {
#                        'userid' => '37'
#                        'gui_access' => '0',
#                        'debug_mode' => '0',
#                        'users_status' => '0',
#                        'ad' => {
#                                 'userAccountControl' => '512',
#                                 'samaccountName' => 'user2'
#                                },
#                       },
#           }
# }

# gui_access   0 - (по умолчанию) использование метода аутентификации системы по умолчанию
#              1 - использование внутренней аутентификации
#              2 - использование LDAP аутентификации
#              3 - деактивация доступа к веб-интерфейсу
#
# debug_mode   0 - режим отладки деактивирован
#              1 - режим отладки активирован
#
# users_status 0 - пользователь активирован
#              1 - пользователь деактивирован
#
# samaccountName     - user name from AD
# userAccountControl  514 - пользователь в AD деактивирован
#                     512 - пользователь в AD активирован

foreach my $alias ( keys %{ $zbbx_user{user} } ) {


  # Сценарий 1
  # user from zabbix server:    пользователь есть
  #                             аутентификация по умолчанию или деактивирован доступ к веб-интерфейсу
  #                             пользователь активирован
  # user from active directory: пользователь с таким в username AD нет

  if ( defined $zbbx_user{user}{$alias}{gui_access}  and
       defined $zbbx_user{user}{$alias}{users_status}  and
     ! defined $zbbx_user{user}{$alias}{ad}  and
     ( $zbbx_user{user}{$alias}{gui_access} == 0 or $zbbx_user{user}{$alias}{gui_access} == 3 ) and
     $zbbx_user{user}{$alias}{users_status} == 0 ) {
    print "User info anomaly    $alias  userid($zbbx_user{user}{$alias}{userid})\n";
    }


  # Сценарий 2
  # user from zabbix server:    пользователь есть
  #                             аутентификация по умолчанию или деактивирован доступ к веб-интерфейсу
  #                             пользователь деактивирован
  # user from active directory: пользователь с таким в username AD есть, учетная запись в AD активирована

  if ( defined $zbbx_user{user}{$alias}{ad}{userAccountControl} and
       defined $zbbx_user{user}{$alias}{gui_access} and
       defined $zbbx_user{user}{$alias}{users_status} and
       ( $zbbx_user{user}{$alias}{gui_access} == 0 or $zbbx_user{user}{$alias}{gui_access} == 3 ) and
       $zbbx_user{user}{$alias}{users_status} == 1 and
       $zbbx_user{user}{$alias}{ad}{userAccountControl} == 512 ) {
    # Найден кандидат у которого учетная запись в AD активирована, а в мониторинге деактивирована
    # Нужно активировать такую учетную запись, активация происходит путем удаление из списка групп - группы указанной тут $work{zbbx}{group}{deactivated}{name}
    # Но может случиться так что группа указанная тут $work{zbbx}{group}{deactivated}{name} единственная группа которая есть у пользователя
    # В этом случае мы сообщим об этом на экран и никаких действий предпринимать не будем

    my %res = $Handle_zabbix->get_user_usrgrpid( $zbbx_user{user}{$alias}{userid} );
    if ( ( scalar keys %res ) >= 2 ) {
      if ( defined $work{zbbx}{group}{deactivated}{users}{  $zbbx_user{user}{$alias}{userid} }  ) {
        # удалим из массива массива на деактивацию найденного кандидата у которого две или более групп
        # поставим признак на то что были изменения и их нужно прогрузить в мониторинг
        delete $work{zbbx}{group}{deactivated}{users}{  $zbbx_user{user}{$alias}{userid} };
        $work{zbbx}{group}{deactivated}{changes} = 1;
        print "User Action unblock   $alias  userid($zbbx_user{user}{$alias}{userid})\n";
        }
      }
    else {
      print "User non-unblock !!!  $alias  userid($zbbx_user{user}{$alias}{userid})\n";
      }
    }


  # Сценарий 3
  # user from zabbix server:    пользователь есть
  #                             аутентификация по умолчанию или деактивирован доступ к веб-интерфейсу
  #                             пользователь активирован
  # user from active directory: пользователь с таким в username AD есть, учетная запись в AD заблокирована

  if ( defined $zbbx_user{user}{$alias}{ad}{userAccountControl} and
       defined $zbbx_user{user}{$alias}{gui_access} and
       defined $zbbx_user{user}{$alias}{users_status} and
       ( $zbbx_user{user}{$alias}{gui_access} == 0 or $zbbx_user{user}{$alias}{gui_access} == 3 ) and
       $zbbx_user{user}{$alias}{users_status} == 0 and
       $zbbx_user{user}{$alias}{ad}{userAccountControl} == 514 ) {

    # Найден кандидат у которого учетная запись в AD заблокирована, а в мониторинге активирована
    # Нужно деактивировать такую учетную запись
    # Проверим в массиве, а нет ли там этого кандидата которого нужно разблокировать
    if ( ! defined $work{zbbx}{group}{deactivated}{users}{  $zbbx_user{user}{$alias}{userid} }  ) {
      # если нет, тогда добавим
      # поставим признак на то что были изменения и их нужно прогрузить в мониторинг
      $work{zbbx}{group}{deactivated}{users}{  $zbbx_user{user}{$alias}{userid} } = 1;
      $work{zbbx}{group}{deactivated}{changes} = 1;
      print "User Action dismissed $alias  userid($zbbx_user{user}{$alias}{userid})\n";
      }
    }
  }


if ( defined $work{zbbx}{group}{deactivated}{changes} ) {
  my @mass = ();
  if ( ( scalar keys %{ $work{zbbx}{group}{deactivated}{users} } ) >= 1  ) {
    foreach my $userid ( keys %{ $work{zbbx}{group}{deactivated}{users} } ) {
      push ( @mass , $userid );
      }
    }
  # В массиве @mass полный список участников группы, отсудствующие в списке удалятся, новые добавятся
  $Handle_zabbix->set_usergroup_usrgrpid ( $work{zbbx}{group}{deactivated}{id} , "@mass");
  }

