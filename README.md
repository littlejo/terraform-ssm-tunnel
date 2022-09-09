
This terraform module allows to communicate with a resource via an SSH tunnel.

I use it to create and configure databases on AWS RDS instances but it can be
used to access any target/port. My RDS instances
are connected to private subnets only and, so,
cannot be accessed directly from the desktop I'm running terraform on.
Running terraform on a host inside the VPC could be a solution but too complex
to install and manage. An easier solution was to access my resources via
an SSH tunnel on an SSH bastion host. Everything you need is a host which can
connect to your private resources and that you can access from your client using SSH (this is generally named 'bastion host').

Please note that, when the 'create' input variable is false or the 'gateway_host' input variable is an empty string, no tunnel
is created and the target host and port are returned, causing a direct connection to the target. So, input variables are used to decide whether a
tunnel is wanted or not.

## SSH command and options

By default, the module will use the 'ssh' string to launch the SSH client
executable. This implies, among others that running 'ssh <bastion host>'
opens a connection to the bastion host (without asking any confirmation).

But you may need to modify this string if, for instance, you want to:

- specify an absolute path and/or a different name when your SSH client is not in
  your path or has a different name (some use 'openssh')
- Add options to pass to the SSH command like, '-o StrictHostKeyChecking=no'
  to avoid failures on non-registered bastions or '-i \<key>' to specify an
  alternate private key.

Specifying an alternate SSH command is done by setting the 'ssh_cmd' variable
to the command with options.

Please note that the SSH process inherits your environment, including a
possible SSH agent configuration to retrieve your private key.

## Target host name resolution

When supplying the target DNS name, note that the name will be resolved by the
bastion host, not by the client you're running terraform on. So, you can use a private
DNS name, like 'xxxx.csdfkzpf0iww.eu-west-1.rds.amazonaws.com'
without having to convert it to an IP address first.

## Combining multiple providers

As you can see in the example below, using a provider alias is encouraged as
it is cleaner and makes it possible from a single provider to combine access to
multiple targets, either tunneled or not.

## Examples

### SSM

    module "ssh_tunnel" {
      source = "github.com/littlejo/terraform-ssm-tunnel"
    
      target_host  = split("https://", data.aws_eks_cluster.this.endpoint)[1]
      target_port  = "443"
      aws_profile  = "YOUR_PROFILE_TO_ACCESS_YOUR_BASTION"
      gateway_user = "ec2-user"
    
      ssm_instance_name = "bastion"
    }
    
    data "aws_eks_cluster" "this" {
      name = "eks_cluster"
    }

### SSH

    # On AWS, if your bastions are in an autoscaling group,here's a way
    # to get a public IP address to use as gateway :

    data aws_instances bastions {
      instance_tags = {
        "aws:autoscaling:groupName" = "replace_with_bastion_autoscaling_group_name"
      }
    }
    
    #----
    
    module db_tunnel {
      # You can also retrieve this module from the terraform registry
      source       = "flaupretre/tunnel/ssh"
      version      = "1.5.0"

      target_host  = aws_db_instance.mydb.address
      target_port  = aws_db_instance.mydb.port

      gateway_host = data.aws_instances.bastions.public_ips[0]
    }
    
    #----
    
    provider mysql {
      alias    = "tunnel"

      endpoint = "${module.db_tunnel.host}:${module.db_tunnel.port}"

      # Target credentials
      username = aws_db_instance.mydb.username
      password = aws_db_instance.mydb.password
    }
    
    #---- DB resources
    
    resource mysql_database this {
      provider = mysql.tunnel
      name = local.name
    }
    
    resource mysql_user user {
      provider = mysql.tunnel
      ....

You may also be interested by the
[terraform-ssh-tunnel-databases](https://github.com/flaupretre/terraform-ssh-tunnel-databases)
module, which uses SSH tunnels to manage MySql/PostgreSql databases, roles, and
permissions.


<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [external_external.free_port](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.ssh_tunnel](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | aws profile | `string` | `""` | no |
| <a name="input_create"></a> [create](#input\_create) | If false, do nothing and return target host | `bool` | `true` | no |
| <a name="input_gateway_host"></a> [gateway\_host](#input\_gateway\_host) | Name or IP of SSH gateway - empty string if no gateway (direct connection) | `any` | `""` | no |
| <a name="input_gateway_port"></a> [gateway\_port](#input\_gateway\_port) | Gateway port | `number` | `22` | no |
| <a name="input_gateway_user"></a> [gateway\_user](#input\_gateway\_user) | User to use on SSH gateway (default = empty string = current username) | `any` | `""` | no |
| <a name="input_local_host"></a> [local\_host](#input\_local\_host) | Local host name or IP. Set only if you cannot use the '127.0.0.1' default value | `string` | `"127.0.0.1"` | no |
| <a name="input_python_cmd"></a> [python\_cmd](#input\_python\_cmd) | Command to run python | `string` | `"python"` | no |
| <a name="input_shell_cmd"></a> [shell\_cmd](#input\_shell\_cmd) | Command to run a shell | `string` | `"bash"` | no |
| <a name="input_ssh_cmd"></a> [ssh\_cmd](#input\_ssh\_cmd) | Shell command to use to start ssh client | `string` | `"ssh -o StrictHostKeyChecking=no"` | no |
| <a name="input_ssh_tunnel_check_sleep"></a> [ssh\_tunnel\_check\_sleep](#input\_ssh\_tunnel\_check\_sleep) | extra time to wait for ssh tunnel to connect | `string` | `"0s"` | no |
| <a name="input_ssm_instance_name"></a> [ssm\_instance\_name](#input\_ssm\_instance\_name) | ssm instance name (for aws) | `string` | `""` | no |
| <a name="input_target_host"></a> [target\_host](#input\_target\_host) | The target host. Name will be resolved by gateway | `string` | n/a | yes |
| <a name="input_target_port"></a> [target\_port](#input\_target\_port) | Target port number | `number` | n/a | yes |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout value ensures tunnel won't remain open forever | `string` | `"30m"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_host"></a> [host](#output\_host) | Host to connect to |
| <a name="output_kubernetes_host"></a> [kubernetes\_host](#output\_kubernetes\_host) | Host to connect to |
| <a name="output_port"></a> [port](#output\_port) | Port number to connect to |
<!-- END_TF_DOCS -->
