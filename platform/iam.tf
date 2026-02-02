resource "aws_iam_role" "s3" {
  count = local.workspace.iam.enabled ? 1 : 0
  name  = "hevo-s3-permission-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "AWS": "arn:aws:iam::231192882420:root"
            },
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "hevo-role-external-id"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "AWS": [
                  "arn:aws:iam::231192882420:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_PowerUserAccess_de82a85fff074f37",
                  "arn:aws:iam::231192882420:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_PowerUserAccess_2cdfe0f4a7195e2e",
                  "arn:aws:iam::231192882420:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_awsssoDataAnalystAccess_37b262b28413167c"
                ]
            }
        }
    ]
}
EOF
}



resource "aws_iam_role_policy_attachment" "s3" {
  count      = local.workspace.iam.enabled ? 1 : 0
  role       = aws_iam_role.s3[count.index].name
  policy_arn = aws_iam_policy.s3[count.index].arn
}

resource "aws_iam_policy" "s3" {
  count = local.workspace.iam.enabled ? 1 : 0
  name  = "hevo-s3-permission-policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
            "Sid": "S3",
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": [
                "arn:aws:s3:::voyantis-jdtay-predictions",
                "arn:aws:s3:::voyantis-jdtay-predictions/*",
                "${aws_s3_bucket.bucket["data-engineering-hevo-dump"].arn}",
                "${aws_s3_bucket.bucket["data-engineering-hevo-dump"].arn}/*",
                "arn:aws:s3:::lly-edp-landing-us-east-2-dev/*",
                "arn:aws:s3:::lly-edp-landing-us-east-2-dev"
            ]
    },
    {
            "Sid": "Kjdtayevo",
            "Effect": "Allow",
            "Action": ["KMS:DescribeKey"],
            "Resource": [
              "*"
            ]
    }
  ]
}
POLICY
}