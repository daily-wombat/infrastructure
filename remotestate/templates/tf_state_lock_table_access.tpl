{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",

      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],

      "Resource": "arn:aws:dynamodb:*:*:table/${state_lock_table}"
    }
  ]
}