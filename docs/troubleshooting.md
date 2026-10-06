# Troubleshooting

## Build fails on a fresh clone
Check that `local.properties` exists and points at an installed SDK.
`check-prerequisites.bat` reports what is missing.

## OTP email never arrives
Verify the mail provider credentials on the backend. In development the
OTP is also written to the backend log.

## Photos show as broken images
Private B2 buckets need a signed download URL; make sure the backend
returns the full URL rather than the bare object key.

## App cannot reach the API
Confirm the device has network access and that the backend URL in
`core` matches the deployed instance.
