#!/usr/bin/env python3
"""새 iOS 버전을 만들고 docs/v3/store.md 문구와 심사 메모를 반영한다.
실행: python3 tool/asc_release.py 1.1.0
"""
import re
import sys

sys.path.insert(0, "tool")
from asc import call  # noqa: E402

APP = "6821653231"
version = sys.argv[1]
md = open("docs/v3/store.md", encoding="utf-8").read()


def limited(label):
    return re.search(rf"<!-- limit:\d+ -->\n{label}: (.*)", md).group(1).strip()


description = re.search(r"limit:4000 begin -->\n(.*?)<!-- limit:4000 end", md, re.S).group(1).strip()
# iOS에서 확인한 내용. Android는 확인 전이라 공용 문구에는 없다.
description = description.replace(
    "• 백색소음 · 갈색소음\n", "• 백색소음 · 갈색소음\n• 화면을 꺼도 소리는 계속 나와요\n")

versions = call("GET", f"/v1/apps/{APP}/appStoreVersions?limit=5")["data"]
v = next((x for x in versions if x["attributes"]["versionString"] == version), None)
if not v:
    v = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
             "attributes": {"platform": "IOS", "versionString": version, "copyright": "2026 olv.is",
                            "releaseType": "AFTER_APPROVAL"},
             "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]
vid = v["id"]
print("version", version, vid, v["attributes"]["appVersionState"])

locs = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]
loc = next(x["id"] for x in locs if x["attributes"]["locale"] == "ko")
call("PATCH", f"/v1/appStoreVersionLocalizations/{loc}", {"data": {"type": "appStoreVersionLocalizations", "id": loc,
     "attributes": {"description": description,
                    "keywords": limited("App Store 키워드"),
                    "promotionalText": limited("App Store 프로모션"),
                    "whatsNew": limited("업데이트 문구"),
                    "supportUrl": "https://looinlabs.com/fokko/"}}})
print("문구 반영", len(description))

old = call("GET", f"/v1/appStoreVersions/{version and vid}/appStoreReviewDetail")
notes = open("docs/v3/review-notes.txt", encoding="utf-8").read().strip()
prev = call("GET", f"/v1/apps/{APP}/appStoreVersions?limit=5&include=appStoreReviewDetail")
contact = next((x["attributes"] for x in prev.get("included", []) if x["type"] == "appStoreReviewDetails"
                and x["attributes"].get("contactEmail")), {})
attrs = {"notes": notes, **{k: contact[k] for k in
         ("contactFirstName", "contactLastName", "contactPhone", "contactEmail") if contact.get(k)}}
if old.get("data"):
    call("PATCH", f"/v1/appStoreReviewDetails/{old['data']['id']}", {"data": {"type": "appStoreReviewDetails",
         "id": old["data"]["id"], "attributes": attrs}})
else:
    call("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
         "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
print("심사 메모 반영", len(notes), "연락처", sorted(k for k in attrs if k != "notes"))
