ec2_adapter = {Overseer.Adapters.EC2,
              [
                prefix: "test_ec2_",
                image: "ami-31bb8c7f",
                type: "t2.nano",
                spot?: true
              ]}

local_adapter = {Overseer.Adapters.Local, [prefix: "test_local_"]}

opts = [
  strategy: :simple_one_for_one,
  max_nodes: 10
]

release = OverseerTest.Utils.get_path("apps/tarball/example_app.tar.gz")
