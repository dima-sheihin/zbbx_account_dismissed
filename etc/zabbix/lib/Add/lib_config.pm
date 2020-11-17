package Add::lib_config;

use strict;
use warnings;
use vars qw(@ISA);
use utf8;

use Config::JSON;
#-------------------------------------------------------------------------------------------

sub new {
my $instance = shift;
my $class = ref($instance) || $instance;

my $f_name = shift;     # Поступил параметр, полный путь до файла

my $self = {
    'f_handle'   => undef,             # Идентификатор файла
    'full_name'  => $f_name,           # Полное имя файла

    };
bless($self, $class);
return $self;
}

#-------------------------------------------------------------------------------------------

sub get {
my $self = shift;
my $in_env = shift;         # входящий параметр - запрашиваемая переменная
my $in_env_default = shift; # входящий параметр - запрашиваемая переменная

# Текущий идентификатор файла
my $handle;

if ( ! defined $self->{'f_handle'} )
  {
  # Мы зашли и запрашиваем первый раз
  if( -f $self->{'full_name'} )
    {
    # Файл есть
    $handle = Config::JSON->new( $self->{'full_name'} );
    }
  else
    {
    # Файла нет, создадим
    $handle = Config::JSON->create( $self->{'full_name'} );
    }
  $self->{'f_handle'} = $handle;
  }
else
  {
  # Мы зашли и запрашиваем уже созданный ранее объект
  $handle = $self->{'f_handle'};
  }

my $env;

# Получаем данные с файла, передавая параметр
$env = $handle->get($in_env);

if ( ! defined $env )
  {
  # Переменная не считана, вероятно ее нет в настроечном файле
  # print "$config_env переменная не считана, вероятно ее нет в настроечном файле \n";

  if ( defined $in_env_default )
    {
    # Определена переменная по умолчанию которую можно присунуть
    # print "$config_env  Определена переменная по умолчанию которую можно присунуть - $config_default \n";

    if ( $self->set( $in_env, $in_env_default) )
      {
      # print "$config_env  Запись произведена успешно, вычитываем с файла переменную\n";
      # Запись произведена успешно, вычитываем с файла переменную
      $env = $handle->get($in_env);
      }
    else
      {
      # Данные в файл не написаны !
      print "canot write config file, exit";
      exit;
      }
    }
  else
    {
    # Переменная по умолчанию не определена, присовывать нечего
    # print "Переменная по умолчанию не определена присовывать нечего\n";
    $env = "nul";
    }
  }
return $env;
}
#-------------------------------------------------------------------------------------------

sub set {
my $self = shift;
# Записываем переменную

my $in_env         = shift; # Запрашиваемая переменная
my $in_env_value   = shift; # Значение переменной

my $handle = $self->{'f_handle'};

my $a = $handle->set($in_env,$in_env_value);

return $a;
}
#-------------------------------------------------------------------------------------------

1;